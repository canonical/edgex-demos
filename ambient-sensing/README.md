# ambient-sensing
Ambient Sensing with EdgeX and DHT22/DHT11 sensors.

![](https://raw.githubusercontent.com/canonical/edgex-demos/main/ambient-sensing/figures/overview.svg)

The document walks you through setting up the EdgeX stack to collect ambient sensing measurements from an MQTT broker. It will showcase the following aspects of EdgeX:
- Deployment using Snaps, allowing automatic updates out of the box
- Devices (sensors) and their resources (sensor measurement classes) added to EdgeX's Metadata store
- Sensor measurements ingested into EdgeX, for storage and further processing
- Creation of an Ubuntu Core OS image, preloaded with the EdgeX stack

We will use the following hardware and OS:
- Raspberry Pi 4 running `arm64` Ubuntu Core (hostname: `jupiter`), to run the EdgeX stack.
- Raspberry Pi Zero W running `armhf` Raspberry Pi OS (hostname: `pluto`) to collect data from a connected DHT22 sensor.


Tools:
- [Mosquitto](https://snapcraft.io/mosquitto) which provides mqtt client for publishing and subscribing to MQTT brokers. Note that the snap also installs the broker which we don't need and stop and disable using `sudo snap stop --disable mosquitto`. We use the clients to subscribe to the broker. You can use any other MQTT client.
- [EdgeX CLI](https://snapcraft.io/edgex-cli) which is a wrapper for various EdgeX REST APIs. 
- [HTTPie HTTP Client](https://snapcraft.io/httpie) which provides the `http` command. It is easy to use and prints pretty JSON output! We use this to interact with the HTTP APIs. You can use any other HTTP client.
- [YQ](https://snapcraft.io/yq) to validate YAML files and convert them to JSON.
- [ubuntu-image](https://snapcraft.io/ubuntu-image) to build the Ubuntu Core image.


It is a good idea to read through the [Getting Started using Snaps](https://docs.edgexfoundry.org/2.2/getting-started/Ch-GettingStartedSnapUsers) before working on this walk-through or at any point to better understand the concepts.

## Install the EdgeX platform

The [EdgeX platform snap](https://snapcraft.io/edgexfoundry), called `edgexfoundry`, contains the core and several other components. We need to install this on `jupiter`.

To install the latest stable:
```bash
$ sudo snap install edgexfoundry
edgexfoundry 2.2.0+2 from Canonical✓ installed
```

After installation, a set of Secret Store tokens get created which are valid for 1 hour. 
This means if these tokens aren't used and refreshed within 1 hour, they will get expired.

Use the following commands to extend the validity to 72 hours while working on the demo:
```bash
sudo snap set edgexfoundry app-options=true
sudo snap set edgexfoundry apps.security-secretstore-setup.config.tokenfileprovider-defaulttokenttl=72h
sudo snap restart edgexfoundry.security-secretstore-setup
```

<!-- ## Install the MQTT broker

We use [Mosquitto](https://snapcraft.io/mosquitto)'s snap and install it on `jupiter`:

```bash
$ sudo snap install mosquitto
mosquitto 2.0.14 from Mosquitto Team (mosquitto✓) installed
```
This installed the broker and well as the Mosquitto clients for publishing/subscribing using the CLI.

By default, the server binds to the loopback interface. This can be verified by running `sudo ss -tulnp | grep 1883`.

Since we would like to connect to the broker from another device (`pluto`), we should change the configurations an listen to the appropriate or all interfaces:
```
$ sudo cp /var/snap/mosquitto/common/mosquitto_example.conf /var/snap/mosquitto/common/mosquitto.conf

$ sudo vi /var/snap/mosquitto/common/mosquitto.conf 
# Add the following lines:
# listener 1883 0.0.0.0
# allow_anonymous true

$ sudo snap restart mosquitto
Restarted.

$ sudo ss -tulnp | grep 1883
tcp   LISTEN 0      100                             0.0.0.0:1883        0.0.0.0:*                                                                                users:(("mosquitto",pid=72270,fd=4))          
``` -->

## Setup the sensing input

We assume that a sensor has been setup on `pluto` and the measurements for temperature and humidity are published to an MQTT broker at an interval. Setting up sensors and publishing their data to the broker is beyond the scope of this demo. 

We use [DHT-MQTT](https://github.com/farshidtz/dht-mqtt) to read data a DHT22 sensor on `pluto` and publish to the [test.mosquitto.org](https://test.mosquitto.org/) public broker. The configuration is as follows:
```bash
MQTT_BROKER=test.mosquitto.org
MQTT_BROKER_PORT=1883
MQTT_TOPIC_PREFIX=edgex-demo/pluto/pluto-dht22
MQTT_CLIENT_ID_PREFIX=pluto
PIN=4
SENSOR=DHT22
INTERVAL=10
```

Let's subscribe to the broker to verify the flow of sensing data:
```bash
$ mosquitto_sub -h test.mosquitto.org -t "edgex-demo/#"  -v
edgex-demo/pluto-dht22/temperature 25.3
edgex-demo/pluto-dht22/humidity 40.4
edgex-demo/pluto-dht22/temperature 25.3
edgex-demo/pluto-dht22/humidity 40.6
...
```

The topics have `../<device>/<resource>` format; we only care about the last two parts to map measurements to the EdgeX device and resource setup in the next step. The payloads are the raw measurements, without any envelop object.

## Setup the EdgeX MQTT service

Install the [EdgeX Device MQTT](https://snapcraft.io/edgex-device-mqtt) service on `jupiter`:
```bash
$ sudo snap install edgex-device-mqtt
edgex-device-mqtt 2.2.0 from Canonical✓ installed
```

The service is NOT started by default. We need to configure and then start it.

Enter the snap's resource directory:
```bash
cd /var/snap/edgex-device-mqtt/current/config/device-mqtt/res
```
All following commands are relative to this path, so make sure you don't change directory.

Remove the default profile and device so that they aren't loaded by the service:
```bash
sudo rm profiles/mqtt.test.device.profile.yml
sudo rm devices/mqtt.test.device.toml
```
Those files are still available as read-only under `/snap/edgex-device-mqtt/current/config/device-mqtt/res/`.

Add `profiles/temperature-humidity-sensor.yml`:
```yml
name: "temperature-humidity-sensor"
deviceResources:
- name: temperature
  properties:
    valueType: "Float32"
    readWrite: "R"
- name: humidity
  properties:
    valueType: "Float32"
    readWrite: "R"
```

Add `devices/dht22.toml`:
```toml
[[DeviceList]]
  Name = "pluto-dht22"
  ProfileName = "temperature-humidity-sensor"
  [DeviceList.Protocols]
    [DeviceList.Protocols.mqtt]
       CommandTopic = "CommandTopic"
```

Update the server configurations with snap option:
```bash
sudo snap set edgex-device-mqtt app-options=true
sudo snap set edgex-device-mqtt config.mqttbrokerinfo-host=test.mosquitto.org
sudo snap set edgex-device-mqtt config.mqttbrokerinfo-clientid=""
sudo snap set edgex-device-mqtt config.mqttbrokerinfo-usetopiclevels=true
sudo snap set edgex-device-mqtt config.mqttbrokerinfo-incomingtopic=edgex-demo/#
```
We are removing the default client id to make the client generate a random ID. It is important to do this to avoid conflicts, especially because we are using a public broker.

This is equivalent to updating the following entries in the config file before service has started for the first time:
```toml
[MQTTBrokerInfo]
Host = "test.mosquitto.org"
ClientId = ""
UseTopicLevels = true
IncomingTopic = "edgex-demo/#"
```

With the configurations in place, we can now start the service:
```bash
sudo snap start edgex-device-mqtt
```

> 🛑 **Debug**  
> Check the logs to see if there are errors:
> ```bash
> sudo snap logs -f edgex-device-mqtt
> ```
> To see if all messages pass through, enable the debugging first as below and then query the logs:
> ```bash
> sudo snap set edgex-device-mqtt config.writable-loglevel=DEBUG
> sudo snap restart edgex-device-mqtt
> ```

> ℹ **Tip**  
> To change the device/device profile after service has started: Update the local files, then delete the device/profile from core-metadata, and restart as below:
>
> ```bash
> # Delete device:
> edgex-cli device rm --name=pluto-dht22
> # or:
> # http DELETE http://localhost:59881/api/v2/device/name/pluto-dht22
>
> # Delete profile, if modified:
> edgex-cli deviceprofile rm --name=temperature-humidity-sensor
> # or:
> # http DELETE http://localhost:59881/api/v2/deviceprofile/name/temperature-humidity-sensor
>
> # Restart:
> sudo snap restart edgex-device-mqtt
> ```

## Query stored data from EdgeX
Refer to [Core Data API docs](https://docs.edgexfoundry.org/2.2/api/core/Ch-APICoreData/) to get familiar with the API endpoints.

Let's query EdgeX Core Data to check if measurements (readings) are being added via Device MQTT. To query locally, on `jupiter`:

Using EdgeX CLI:
```bash
$ edgex-cli reading list --limit=2
Origin               Device       ProfileName                  Value         ValueType
28 Jun 22 15:23 UTC  pluto-dht22  temperature-humidity-sensor  4.020000e+01  Float32
28 Jun 22 15:23 UTC  pluto-dht22  temperature-humidity-sensor  2.630000e+01  Float32
...
```
 
Or using HTTPie, we call the `reading` endpoint for our device and query 2 records:
```bash
http http://localhost:59880/api/v2/reading/device/name/pluto-dht22?limit=2 --body
```
```json
{
    "apiVersion": "v2",
    "readings": [
        {
            "deviceName": "pluto-dht22",
            "id": "20fa82bd-5de7-4e53-a962-c3846b859376",
            "origin": 1656429787689978119,
            "profileName": "temperature-humidity-sensor",
            "resourceName": "humidity",
            "value": "4.020000e+01",
            "valueType": "Float32"
        },
        {
            "deviceName": "pluto-dht22",
            "id": "a6051b94-6d4c-4bdf-99ea-16a85b1e5a37",
            "origin": 1656429787623342364,
            "profileName": "temperature-humidity-sensor",
            "resourceName": "temperature",
            "value": "2.630000e+01",
            "valueType": "Float32"
        }
    ],
    "statusCode": 200,
    "totalCount": 2478
}
```

Querying from another device is possible via the API Gateway and with appropriate credentials.
Refer to the [docs](https://docs.edgexfoundry.org/2.2/getting-started/Ch-GettingStartedSnapUsers/#adding-api-gateway-users) to learn how to add a user and pass its token to query externally.

<!-- ## Visualize sensor data with Grafana
We use Grafana to query the readings from EdgeX Core Data. We use a Grafana plugin called [JSON API](https://grafana.com/grafana/plugins/marcusolsson-json-datasource/)to query and pick the needed information.

#### Install
```bash
sudo snap install grafana --channel=rock/edge
sudo snap start --enable grafana
```
Open UI: http://jupiter.local:3000

Default username/password: admin/admin

#### Install JSON API Plugin
Install the [JSON API](http://localhost:3000/plugins/marcusolsson-json-datasource?page=overview) plugin via "configuration->plugin":
[http://localhost:3000/plugins/marcusolsson-json-datasource?page=overview](http://localhost:3000/plugins/marcusolsson-json-datasource?page=overview))

#### Add a datasource
Select JSON API and set the following parameters:
* name: core-data  
* URL: http://localhost:59880/api/v2/reading

Save and test. You should see Not Found as follows, meaning that the server was set correctly but there is no resource at the given URL. To resolve this, we will later on set the HTTP path in the query editor.


#### Create a dashboard
To do so, go follow: + -> Create / Dashboard

Set the query refresh rate to `5s`

> ℹ **Tip**  
> The range can be shorted by manually entering the from value such as: now-1m

#### Setup the panel
a. Add an empty panel. Set the title to Temperature.

b. Setup query and transformation:
-   Name `Pluto`
-   Field `$.readings[:].value`, Type `Boolean`, Alias `Value`
-   Field `$.readings[:].origin`, Type `String`, Alias `Time(ns)`
-   Path: `/device/name/pluto-dht22/resourceName/temperature` (this gets appended to the server URL set in datasource configuration to construct the core-data reading endpoint as `http://localhost:59880/api/v2/reading/device/name/pluto-dht22/resourceName/temperature`)
-   Param key `limit`, value `100` (this is the number or readings queried from core-data)
-   Cache time: `0s` (otherwise, the datasource won’t query the core-data on refresh!)

At this point, we should be able to see data on a table.

To visualize time series as line graph, we need to add two transformation:

c. In the Transform tab in the query editor:
-   Select "Add field from calculation":
-   Binary operation, `Time(ns)`/`1000000`, Alias `Time`. This converts the time in nanos to seconds
-   Add transformation -> Select "Convert field type"
-   `Time` as `Time`. This converts the time from Number to Time format.


Auto refresh doesn’t work in the query editor, but only on the dashboard. Refresh manually here to see new results.

Save and go back to the dashboard view. It should auto refresh every 5s as previously configured.

Setup a panel for humidity by cloning the Temperature panel and changing the relevant fields. -->

## Create an OS image with all the above
Now, let's create an [Ubuntu Core](https://ubuntu.com/core) OS image that includes all the above (except for the sensing part) that can be easily flashed on a storage medium to create a bootable drive. This will make it very easy to onboard gateway devices preloaded with the EdgeX stack!

Perform the following steps on your personal computer.

### Create a config provider for device-mqtt
The EdgeX Device MQTT service cannot be fully configured using environment variables / snap options. Because of that, we need to package the modified config files and replace the defaults.

Since we want to create an OS image pre-loaded with the configured system, we need to make sure the configurations are there without any manual user interaction. We do that by creating a snap which provides the configuration files prepared in the previous steps to the Device MQTT snap:
- configuration.toml
- devices/dht22.toml
- profiles/temperature-humidity-sensor.yml

This snap should be build and uploaded to the store. We use `edgex-demo-ambient-sensing-config` as the snap name. 

The source code is available at [./config-provider](./config-provider). You may refer to [docs](https://docs.edgexfoundry.org/2.2/getting-started/Ch-GettingStartedSnapUsers/#config-provider-snap) for more details.

Build:
```
$ snapcraft
...
Snapped edgex-demo-ambient-sensing-config_demo_amd64.snap
```

This will build for your host architecture, so if your machine is `arm64`, it will result in a snap that has the same architecture. You can perform [remote builds](https://snapcraft.io/docs/remote-build) to build for other architectures.

Let's upload the `arm64` snap and release it to the `latest/edge` channel:
```
snapcraft upload --release=latest/edge ./edgex-demo-ambient-sensing-config_demo_amd64.snap
```

### Create an Ubuntu Core model assertion
The model assertion is a document that describes the contents of the OS image. The document needs to be signed by its owner.

Refer to [this article](https://ubuntu.com/core/docs/custom-images#heading--signing) for details on how to sign the model assertion.

1. Create and register a key if you don't already have one:
```bash
snap login
snap keys
# continue if you have no existing keys
# you’ll be asked to set a passphrase which is needed before signing
snap create-key edgex-demo
snapcraft register-key
```
We now have a registered key named `edgex-demo` which we'll use later.

2. Now, create the model assertion.

First, make yourself familiar with the Ubuntu Core [model assertion](https://ubuntu.com/core/docs/reference/assertions/model).

Unlike the official documentation which uses JSON, we use YAML serialization for the model. This is for consistency with all the other serialization formats in this tutorial. Moreover, it allows us to comment out some parts for testing or add comments to describe the details inline.

Create `model.yaml` with the following content:
```yaml
type: model
series: '16'

# authority-id and brand-id must be set to your developer-id
authority-id: SZ4OfFv8DVM9om64iYrgojDLgbzI0eiL
brand-id: SZ4OfFv8DVM9om64iYrgojDLgbzI0eiL

model: ubuntu-core-20-amd64
architecture: amd64

# timestamp should be within your signature’s validity period
timestamp: '2022-06-21T10:45:00+00:00'
base: core20

# grade is set to dangerous because the gadget is not signed nor from the store
grade: dangerous

snaps:
- # This is our custom, dev gadget snap
  # It has no channel and id, because it isn't in the store.
  # We’re going to build it locally and pass it to the image builder. 
  name: pc
  type: gadget
  # default-channel: 20/stable
  # id: UqFziVZDHLSyO3TqSWgNBoAdHbLI4dAH

- name: pc-kernel
  type: kernel
  default-channel: 20/stable
  id: pYVQrBcKmBa0mZ4CCN7ExT6jH8rY1hza

- name: edgexfoundry
  type: app
  default-channel: latest/stable
  id: AZGf0KNnh8aqdkbGATNuRuxnt1GNRKkV

- name: edgex-device-mqtt
  type: app
  default-channel: latest/stable
  id: AeVDP4oaKGCL9fT0u7lbNKxupwXrGiMX

# Config provider for edgex-device-mqtt
- name: edgex-demo-ambient-sensing-config
  type: app
  default-channel: latest/edge
  id: 5riI41SdX1gJYFdFXC5eoKzzBUEzSgqq
```

We haven't included the `core20` Ubuntu Core base and `snapd` snaps because the image builder detects their need and includes them automatically.

> ℹ **Tip**  
> Find your developer ID using CLI:
> ```bash
> $ snapcraft whoami
> ...
> developer-id: SZ4OfFv8DVM9om64iYrgojDLgbzI0eiL
> ```
>
> Or from https://dashboard.snapcraft.io.

The model assertion file is also available at [./ubuntu-core/model.yaml](./ubuntu-core/model.yaml).

3. Sign the model
We sign the model using the `edgex-demo` key created and registered earlier. 

The snap sign command takes JSON as input and produces YAML as output! We use the YQ app to convert our model assertion to JSON before passing it in for signing.

```bash
# sign
yq eval model.yaml -o=json | snap sign -k edgex-demo > model.signed.yaml

# check the signed model
cat model.signed.yaml
```

Note: You need to repeat the signing every time you change the input model, because the signature is calculated based on the model.

### Setup defaults using a Gadget snap
Setting up default snap options and connection is possible via a Gadget snap.

Use one of the following as basis:
- [pc-amd64-gadget](https://github.com/snapcore/pc-amd64-gadget) for amd64 computers. This is what we'll use for the remaining steps.
- [pi-gadget](https://github.com/snapcore/pi-gadget) for Raspberry Pi

Add the following to `gadget.yml`:
```yml
# Add default config options
defaults:
  # edgex-device-mqtt
  AeVDP4oaKGCL9fT0u7lbNKxupwXrGiMX:
    # automatically start the service
    autostart: true

connections:
   -  # Connect edgex-device-mqtt's plug (consumer) to 
      #   edgex-demo-ambient-sensing-config's slot (provider) to override the
      #   default configuration files by bind-mounting provider's "res" directory
      #   on top of the provider's "res" directory.
      plug: AeVDP4oaKGCL9fT0u7lbNKxupwXrGiMX:device-config
      slot: 5riI41SdX1gJYFdFXC5eoKzzBUEzSgqq:device-config
```

Build:
```bash
$ snapcraft
...
Snapped pc_20-0.4_amd64.snap
```

The source code for the gadget snap is available [here](./) (see the submodule).

Note: You need to rebuild the snap every time you change the gadget.yaml file.

### Build the Ubuntu Core image
We use ubuntu-image and set the following:
- Path to signed model assertion YAML file
- Path to gadget snap that we built in the previous steps

```bash
$ ubuntu-image snap model.signed.yaml --validation=enforce --snap pc_20-0.4_amd64.snap 
Fetching snapd
Fetching pc-kernel
Fetching core20
Fetching edgexfoundry
Fetching edgex-device-mqtt
Fetching edgex-demo-ambient-sensing-config
WARNING: "pc" installed from local snaps disconnected from a store cannot be refreshed subsequently!
Copying "pc_20-0.4_amd64.snap" (pc)

# check the image file
$ file pc.img
pc.img: DOS/MBR boot sector, extended partition table (last)
```

The warning is because we side-loaded the gadget for demonstration purposes. In production settings, a custom gadget would need to be uploaded to the [store](https://ubuntu.com/internet-of-things/appstore) to receive updates.

**The image file is now ready to be flashed on a medium to create a bootable drive with the needed applications and configuration!**

You can use one of following to flash the image:
- [Ubuntu Startup Disk Creator](https://ubuntu.com/tutorials/create-a-usb-stick-on-ubuntu)
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- [`dd` command](https://ubuntu.com/download/iot/installation-media)

### Run in an emulator
Instead of flashing the image and booting on actual hardware, we run it in an emulator.
This makes it easier to quickly try the image and find out possible issues.

We use a `amd64` QEMU emulator. You may refer to [Testing Ubuntu Core with QEMU](https://ubuntu.com/core/docs/testing-with-qemu) and [Image building](https://ubuntu.com/core/docs/image-building#heading--testing) for more information.

Run the following command and wait for the boot to complete:
```bash
sudo qemu-system-x86_64 -smp 4 -m 4096  -net nic,model=virtio -net user,hostfwd=tcp::8022-:22  -drive file=/usr/share/OVMF/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on  -drive file=pc.img,cache=none,format=raw,id=disk1,if=none  -device virtio-blk-pci,drive=disk1,bootindex=1 -machine accel=kvm -serial mon:stdio -vga virtio
```
The above command forwards the port 22 of the emulator to 8022 on the host. Refer to the above references on how to SSH.

To forward additional ports, add more `hostfwd=tcp::PORT_ON_HOST-:PORT_IN_EMULATOR` values to `-net`.

Once the boot is complete, it will prompt for your email address to deploy your public key. This manual step can be avoided by pre-loading the image with user data.

Connect to it via SSH
```bash
ssh <user>@localhost -p 8022
```

List the installed snaps:
```
$ snap list
Name                               Version          Rev    Tracking       Publisher      Notes
core18                             20220428         2409   latest/stable  canonical✓     base
core20                             20220527         1518   latest/stable  canonical✓     base
edgex-demo-ambient-sensing-config  demo             3      latest/edge    farshidtz      -
edgex-device-mqtt                  2.2.0            2369   latest/stable  canonical✓     -
edgexfoundry                       2.2.0+2          3722   latest/stable  canonical✓     -
pc                                 20-0.4           x1     -              -              gadget
pc-kernel                          5.4.0-121.137.1  1049   20/stable      canonical✓     kernel
snapd                              2.56             16010  latest/stable  canonical✓     snapd
```

List the snap connections in the system:
```
$ snap connections
Interface                         Plug                                  Slot                                             Notes
content[device-config]            edgex-device-mqtt:device-config       edgex-demo-ambient-sensing-config:device-config  gadget
content[edgex-secretstore-token]  edgexfoundry:edgex-secretstore-token  edgex-device-mqtt:edgex-secretstore-token        -
network                           edgex-device-mqtt:network             :network                                         -
network                           edgexfoundry:network                  :network                                         -
network-bind                      edgex-device-mqtt:network-bind        :network-bind                                    -
network-bind                      edgexfoundry:network-bind             :network-bind                                    -
```

## References
- [Getting Started using Snaps](https://docs.edgexfoundry.org/2.2/getting-started/Ch-GettingStartedSnapUsers)
- [EdgeX Core Data](https://docs.edgexfoundry.org/2.2/microservices/core/data/Ch-CoreData/)
- [Gadget snaps](https://snapcraft.io/docs/gadget-snap)
- [Ubuntu Core](https://ubuntu.com/core)
- [Testing Ubuntu Core with QEMU](https://ubuntu.com/core/docs/testing-with-qemu)
- [Ubuntu Core - Image building](https://ubuntu.com/core/docs/image-building#heading--testing)
- [Ubuntu Core - Custom images](https://ubuntu.com/core/docs/custom-images)
- [Ubuntu Core - Building a gadget snap](https://ubuntu.com/core/docs/gadget-building)
