# Azure IoT Operations MQTT Bridge

## MQTT Bridge between Azure IoT Operations MQ broker and Azure Event Grid

This is the reference setup [documentation](https://learn.microsoft.com/en-us/azure/iot-operations/connect-to-cloud/tutorial-connect-event-grid) and you can follow these [steps](event-grid/README.md) to setup the MQTT bridge between Azure IoT Operations MQ broker and Azure Event Grid.

## MQTT Bridge between 2 Azure IoT Operations MQ brokers (E4K)

In our sample scenario we have 2 Azure IoT Operations MQ brokers and we want to bridge them together.
- Broker #1: AIO running on cluster `iot-oper-01-k8s`
- Broker #2: AIO running on cluster `aio-k8s-03`


## Create testing environment with AIO in cloud

If you need to create a testing environment using an AKS, arc-enabling AKS and then instal Azure IoT Operations, just follow these [steps](setup-new-site/README.md).