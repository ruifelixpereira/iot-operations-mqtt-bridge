#!/bin/bash

#
# Substation Moura
#
kubectl config use-context moura

# Create MQTT Bridge Connector
kubectl apply -f ../../e4k/bridge-setup/simple-scenario/mqtt-bridge.yaml

# Create MQTT Bridge Connector Topic Map
kubectl apply -f ../../e4k/bridge-setup/simple-scenario/topic-map.yaml


k get mqttbridgetopicmap
k get mqttbridgeconnector

kubectl logs azedge-energy-mqtt-bridge-0