##
## makefile
##

PWD := $(shell pwd)
SOURCE := temperature
SINK := hot

default: all

all: build # test

build: src/etc/kuiper.yaml
	docker build -t ${USER}/kuiper src/

push: build
	docker push ${USER}/kuiper

test: stream rule sink source

sink: 
	mosquitto_sub -C 1 -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t ${SINK}

source:
	mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t ${SOURCE} -m '{"temperature":1.0, "date":"'$$(date -u +%FT%TZ)'"}'
	mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t ${SOURCE} -m '{"temperature":2.0, "date":"'$$(date -u +%FT%TZ)'"}'
	mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t ${SOURCE} -m '{"temperature":3.0, "date":"'$$(date -u +%FT%TZ)'"}'
	mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD} -t ${SOURCE} -m '{"temperature":3.1, "date":"'$$(date -u +%FT%TZ)'"}'

stream:
	./sh/mkstream.sh $(SOURCE) "tcp://${MQTT_USERNAME}:${MQTT_PASSWORD}@${MQTT_HOST}:${MQTT_PORT}" $(SOURCE)

rule:
	./sh/mkrule.sh $(SINK) $(SOURCE) "SELECT * WHERE temperature > 3.0" $(SINK)

src/etc/kuiper.yaml: kuiper.yaml.tmpl config.json
	HOST_PORT=$$(jq -r '.ports.host' config.json) \
	  CONTAINER_PORT=$$(jq -r '.ports.container' config.json) \
	  PROMETHEUS_ON=$$(jq '.prometheus.on==true' config.json) \
	  PROMETHEUS_PORT=$$(jq -r '.prometheus.port' config.json) \
          cat kuiper.yaml.tmpl | envsubst > $@

.PHONY: default all build test
