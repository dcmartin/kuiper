
# &#9732; `kuiper` - MQTT relay using SQL rules

## Start `kuiper`
Setup the MQTT broker information to interact with the 
[Home Assistant](http://home-assistant.io) server 
and the [`motion`](http://github.com/dcmartin/hassio-addons/tree/master/motion/README.md)  _add-on_.


```
export MQTT_HOST=192.168.1.50
export MQTT_USERNAME=username
export MQTT_PASSWORD=password
export MQTT_PORT=1883
export KUIPER_VERSION=0.2.1

docker run -d --name kuiper -e MQTT_BROKER_ADDRESS=tcp://${MQTT_USERNAME}:${MQTT_PASSWORD}@${MQTT_HOST}:${MQTT_PORT} emqx/kuiper:${KUIPER_VERSION}
```

## `show` _streams_ and _rules_
The system provides support for _streams_ which read from the MQTT broker according to a specified _topic_ and _rules_ which process data received on a stream.  The inventory can be shown using the following commands:


```
docker exec -it kuiper bin/cli show streams
docker exec -it kuiper bin/cli show rules
```

## Setup a _stream_
A stream may consume from any MQTT broker according to a specified MQTT _topic_.  A pre-defined structure may be defined for the JSON data received, for example the `motion` _add-on_ publishes on the topic `<group>/<device>/<camera>/event/end` information at the end of each motion detection event; for example:

```
{
  "timestamp": "2020-03-25T19:51:19Z",
  "log_level": "debug",
  "debug": false,
  "group": "motion",
  "device": "+",
  "camera": "+",
  "event": {
    "group": "motion",
    "device": "ftpcams",
    "camera": "dogyard",
    "event": "421",
    "start": 1585165867,
    "timestamp": {
      "start": "2020-03-25T19:51:07Z",
      "end": "2020-03-25T19:51:11Z",
      "publish": "2020-03-25T19:51:15Z"
    },
    "id": "20200325195111-421",
    "end": 1585165875,
    "elapsed": 3,
    "images": [
      {
        "device": "ftpcams", "camera": "dogyard", "type": "jpeg", "timestamp": "2020-03-25T19:51:10Z", "date": 1585165870, "seqno": "20200325195110-421-01", "event": "421", "id": "20200325195110-421-01", "center": { "x": 320, "y": 240 }, "width": 100, "height": 100, "size": 10000, "noise": 0 }, 
      ...
    ],
    "date": 1585165875,
    "image": "<BASE64-encoded-original>"
  },
  "old": 300,
  "payload": "image/end",
  "topic": "motion/+/+",
  "services": [ { "name": "mqtt", "url": "http://mqtt" } ],
  "mqtt": { "host": "192.168.1.50", "port": 1883, "username": "username", "password": "password" },
  "yolo": {
    "log_level": "debug",
    "debug": false,
    "timestamp": "2020-03-20T17:51:16Z",
    "date": 1584726676,
    "period": 60,
    "entity": "all",
    "scale": "none",
    "config": "tiny-v3",
    "services": [ { "name": "mqtt", "url": "http://mqtt" } ],
    "darknet": {
      "threshold": 0.25,
      "weights_url": "http://pjreddie.com/media/files/yolov3-tiny.weights",
      "weights": "/openyolo/darknet/yolov3-tiny.weights",
      "weights_md5": "3bcd6b390912c18924b46b26a9e7ff53",
      "cfg": "/openyolo/darknet/cfg/yolov3-tiny.cfg",
      "data": "/openyolo/darknet/cfg/coco.data",
      "names": "/openyolo/darknet/data/coco.names"
    },
    "names": [ "person", "bicycle", .. ]
  },
  "date": 1585165879,
  "info": {
    "type": "JPEG",
    "size": "640x480",
    "bps": "8-bit",
    "color": "sRGB"
  },
  "time": 0.172631,
  "count": 0,
  "detected": null,
  "image": "<BAS64-encoded-annotated>"
}
```

### Drop any existing stream with name `motion`

```
docker exec -it kuiper bin/cli drop stream motion
```

### Create new stream named `motion`

```
docker exec -it kuiper bin/cli create stream motion '(count bigint,detected array(struct(entity string,count bigint)),event struct(device string, camera string)) WITH (FORMAT="JSON", DATASOURCE="+/+/+/event/end/+")'
```

### Describe the new stream

```
docker exec -it kuiper bin/cli describe stream motion
```

## Create a _rule_
Define a SQL statement to extract the information from the stream, for example use `*` to indicate everything defined (or discovered); for example using the interactive command-line:

```
docker exec -it kuiper bin/cli query
select * from motion where count > 0;
quit
```

Rules may also be defined using a JSON structure, for example:

```
cat > rule.txt << EOF
{
  "sql": "SELECT * from motion where count > 0",
  "actions": [
    {
      "mqtt": {
        "server": "tcp://${MQTT_USERNAME}:${MQTT_PASSWORD}@${MQTT_HOST}:${MQTT_PORT}",
        "topic": "kuiper/detected"
      }
    }
  ]
}
EOF
```

This structure may then be submitted to `kuiper` for creation, for example:

```
docker cp rule.txt kuiper:/tmp/rule.txt
docker exec -it kuiper bin/cli create rule rule1 -f /tmp/rule.txt
```

### `getstatus` on a rule
```
docker exec -it kuiper bin/cli getstatus rule rule1
```

```
{
  "source_motion_0_records_in_total": 0,
  "source_motion_0_records_out_total": 0,
  "source_motion_0_exceptions_total": 0,
  "source_motion_0_process_latency_ms": 0,
  "source_motion_0_buffer_length": 0,
  "source_motion_0_last_invocation": 0,
  "op_preprocessor_motion_0_records_in_total": 0,
  "op_preprocessor_motion_0_records_out_total": 0,
  "op_preprocessor_motion_0_exceptions_total": 0,
  "op_preprocessor_motion_0_process_latency_ms": 0,
  "op_preprocessor_motion_0_buffer_length": 0,
  "op_preprocessor_motion_0_last_invocation": 0,
  "op_filter_0_records_in_total": 0,
  "op_filter_0_records_out_total": 0,
  "op_filter_0_exceptions_total": 0,
  "op_filter_0_process_latency_ms": 0,
  "op_filter_0_buffer_length": 0,
  "op_filter_0_last_invocation": 0,
  "op_project_0_records_in_total": 0,
  "op_project_0_records_out_total": 0,
  "op_project_0_exceptions_total": 0,
  "op_project_0_process_latency_ms": 0,
  "op_project_0_buffer_length": 0,
  "op_project_0_last_invocation": 0,
  "sink_sink_mqtt_0_records_in_total": 0,
  "sink_sink_mqtt_0_records_out_total": 0,
  "sink_sink_mqtt_0_exceptions_total": 0,
  "sink_sink_mqtt_0_process_latency_ms": 0,
  "sink_sink_mqtt_0_buffer_length": 0,
  "sink_sink_mqtt_0_last_invocation": 0
}
```

### `drop` a rule
```
docker exec -it kuiper bin/cli drop rule rule1
```

