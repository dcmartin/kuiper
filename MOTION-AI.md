
# &#128738;`kuiper4motion` - `MQTT` relay using `SQL`

This document describes an example use-case for [`kuiper`](http://github.com/dcmartin/kuiper) relaying MQTT traffic for [Motion &Atilde;&#128065;](http://github.com/dcmartin/motion-ai) which provides a set of AI assistants for situational awareness from Web cameras using a combination of the following components:

+ [Home Assistant](http://home-assistant.io) 
+ Home Assistant _add-on_ [`motion`](http://github.com/dcmartin/hassio-addons/tree/master/motion/README.md) 
+ [Open Horizon](http://github.com/open-horizon) _edge_ service [`yolo4motion`](http://github.com/dcmartin/open-horizon/tree/master/services/yolo4motion/README.md)


### Operational Scenario

In this scenario the [`motion`](http://github.com/dcmartin/hassio-addons/tree/master/motion/README.md) _add-on_ for [Home Assistant](http://home-assistant.io) publishes motion detection events to an MQTT broker running on the same device.  The motion detection JSON payloads are consumed by [`yolo4motion`](http://github.com/dcmartin/open-horizon/tree/master/services/yolo4motion/README.md), an [Open Horizon](http://github.com/open-horizon) _edge_ service, which provides object detection and classification using [OpenYOLO](http://github.com/dcmartin/openyolo).

The `kuiper` software provides a relay from the `local` MQTT broker to the `master` MQTT broker, but only transmits a limited set of information, notably the `count` of entities annotated, an _array_ of each entity type and count, and the motion detection event `device` and `camera`.

In this example:

+ `local` - `127.0.0.1`
+ `master` - `192.168.1.50`

_Actor_|Subscribe|Publish|Network
----|----|----|----
`motion`|`local`|`local`|_localhost_
`yolo4motion`|`local`|`local`|_localhost_
`mqtt`|`local`|`local`|_localhost_
`kuiper`|`local`|`master`|_localhost_ & LAN
`homeassistant`|`master`|`master`|LAN

# Instructions
## Step 1 - Start `kuiper`
Setup the MQTT broker information to interact with the 
[Home Assistant](http://home-assistant.io) server 
and the [`motion`](http://github.com/dcmartin/hassio-addons/tree/master/motion/README.md)  _add-on_.


```
export MQTT_HOST=127.0.0.1
export MQTT_USERNAME=username
export MQTT_PASSWORD=password
export MQTT_PORT=1883
export KUIPER_VERSION=0.2.1

docker run -d --name kuiper -e MQTT_BROKER_ADDRESS=tcp://${MQTT_USERNAME}:${MQTT_PASSWORD}@${MQTT_HOST}:${MQTT_PORT} emqx/kuiper:${KUIPER_VERSION}
```

## Step 2 - Start Motion &Atilde;&#128065;

### Step 2.1 - Start `motion` _add-on_
The `motion` _add-on_ publishes information at the end of each motion detection event.  The JSON payload sent to the MQTT topic is specified for a _group_, _device_, and _camera_, respectively; alternatively a `+`may be used for _all_. 

**Please refer to the [`motion-ai`](http://github.com/dcmartin/motion-ai) repository for installation and operation instructions.**

### Step 2.2 - Start `yolo4motion` _service_

```
MOTION_CLIENT='+' ./sh/yolo4motion
```

### Step 2.3 - Monitor `yolo4motion` _service_ 
Listen for end events using `mosquitto_sub` from the `mosquitto-clients` _apt_ package:

```
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t '+/+/+/event/end/+'
```

This command should produce an output similar to the following with notable redactions for BASE64 encoded `image` attributes.

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
  "mqtt": { "host": "127.0.0.1", "port": 1883, "username": "username", "password": "password" },
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

## Step 3 - Streams for `motion` _add-on_
A stream may consume from any MQTT broker according to a specified MQTT _topic_.  A schema may be defined for the JSON data received or a schema will automatically be generared.

Topic|Stream
---|---|
`+/+/+/event/end`|`motion_end`
`+/+/+/event/end/+`|`motion_annotated`

### Step 3.1 - Create stream `motion_end`
This command creates a new stream listening for motion detection end events for any _group_, _device_, _camera_ combination; the schema is left undefined, i.e. `()`, and will be discovered based on JSON payloads received.  **Note:** this command will fail if the stream name is already in-use.

```
docker exec -it kuiper bin/cli create stream motion_end '() WITH FORMAT="JSON", DATASOURCE="+/+/+/event/end"'
```

### Step 3.2 -  Create stream `motion_annotated`
Messages are sent by the `yolo4motion` service as a result of processing the motion detection end event.  In this example the schema is **defined** to include only the `count`, `detected`, and `event` attributes (n.b. see JSON above).  In addition, the `event` schema inclues onlly the `device` and `camera` attributes (see table).

Attribute|Schema
---|---|
count|bigint
detected|array(struct(entity string,count bigint))
event|struct(device string, camera string)

This command creates a new stream listening for motion detection annotation messages

```
docker exec -it kuiper bin/cli create stream motion_annotated \
  '(count bigint,detected array(struct(entity string,count bigint)),event struct(device string, camera string)) WITH (FORMAT="JSON", DATASOURCE="+/+/+/event/end/+")'
```

### Step 3.3 - `show streams`

```
docker exec -it kuiper bin/cli show streams
Connecting to 127.0.0.1:20498... 
motion_annotated
```

### Step 3.4 - `describe`  _stream_

```
docker exec -it kuiper bin/cli describe stream motion_annotated
Connecting to 127.0.0.1:20498... 
Fields
--------------------------------------------------------------------------------
count	bigint
detected	array(struct(entity string, count bigint))
event	struct(device string, camera string)

DATASOURCE: +/+/+/event/end/+
FORMAT: JSON
```

### Step 3.5 - `drop`  _stream_
The `motion_end` stream will not be used further, so it may optionally be deleted or _dropped_; for example:

```
docker exec -it kuiper bin/cli drop stream motion_end
```

## Step 4 - Rules for `motion_annotated` _stream_
Rules may only be created in reference to a previously defined _stream_.

### Step 4.1 -  Create _rule_
Define a SQL statement to extract the information from the stream; use `*` to indicate everything defined (or discovered). For example, using the interactive command-line:

```
docker exec -it kuiper bin/cli query
select * from motion_annotated where count > 0;
quit
```

Rules may also be defined using a JSON structure and provides both an `sql` statement as well as an array of `actions`.  There are two types of action available:

+ `log` - record to a log file or standard output
+ `mqtt` - publish the SQL results as JSON

For example to publish the entire contents of the `motion_annotated` stream payload(s) to the `master` MQTT broker, **if** the `count` of entities detected is positive (**n.b.** `MQTT_HOST` change to `master`):

```
export MQTT_HOST=192.168.1.50
cat > motion_detected.json << EOF
{
  "sql": "SELECT * from motion_annotated where count > 0",
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

Copy the file into the `kuiper` container and create the _rule_, for example:

```
docker cp motion_detected.json kuiper:/tmp/motion_detected.json
docker exec -it kuiper bin/cli create rule motion_detected  -f /tmp/motion_detected.json
```

### Step 4.2 - `describe` _rule_

```
docker exec -it kuiper bin/cli describe rule motion_detected
Connecting to 127.0.0.1:20498... 
{
  "sql": "SELECT * from motion_annotated where count > 0",
  "actions": [
    {
      "mqtt": {
        "server": "tcp://username:password@192.168.1.50:1883",
        "topic": "kuiper/detected"
      }
    }
  ]
}
```

## &#9989; - COMPLETE
The `kuiper` container will continue to relay MQTT payloads from the `local` broker to the `master` broker whenever the count of detected entities is positive.  Subscribe the to `kuiper/detected` topic on the same MQTT broker to observe payloads processed by the rule, for example:

```
export MQTT_HOST=192.168.1.50
mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t 'kuiper/detected'
```

```
[{"count":2,"detected":[{"count":2,"entity":"person"}],"event":{"camera":"foyer","device":"ftpcams"}}]
[{"count":2,"detected":[{"count":2,"entity":"person"}],"event":{"camera":"foyer","device":"ftpcams"}}]
```


# `Command-line reference`

### `drop` _rule_
```
docker exec -it kuiper bin/cli drop rule motion_detected
```

### `show rules`
The system provides support for _streams_ which read from the MQTT broker according to a specified _topic_ and _rules_ which process data received on a stream.  The inventory can be shown using the following commands:

```
docker exec -it kuiper bin/cli show rules
```

### `getstatus` _rule_

```
docker exec -it kuiper bin/cli getstatus rule motion_detected
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
#  Further Information 

# Changelog & Releases

Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors

David C Martin (github@dcmartin.com)

## `CLOC`

Language|files|blank|comment|code
:-------|-------:|-------:|-------:|-------:
Go|99|1950|471|24865
Markdown|79|2053|0|4700
YAML|14|42|62|698
Bourne Shell|6|60|44|201
make|1|19|0|110
JSON|3|1|0|86
Dockerfile|2|12|0|15
--------|--------|--------|--------|--------
SUM:|204|4137|577|30675

## Stargazers
[![Stargazers over time](https://starchart.cc/dcmartin/kuiper.svg)](https://starchart.cc/dcmartin/kuiper)
