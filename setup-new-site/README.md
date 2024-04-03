# Create testing environment with AIO in cloud

If you need to create a testing environment using an AKS, arc-enabling AKS and then instal Azure IoT Operations on it, you can use the scripts provided. Create a copy of the file `settings.template.json` with the name `settings.json`, customize the settings and then you can use the following scripts:

```bash
./site-create-01.sh -r iot-oper-03-rg -s aio-k8s-03

./prep-iot-operations-setup-02.sh -c settings.json

./deploy-iot-operations-03.sh -c settings.json
```
