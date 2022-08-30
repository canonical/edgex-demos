# Temperature Controller Demo

## Set up the hardware
USB to GPIO: https://www.adafruit.com/product/2264
Pinout: https://learn.adafruit.com/circuitpython-on-any-computer-with-ft232h/pinouts

Setup: https://learn.adafruit.com/circuitpython-on-any-computer-with-ft232h/linux

Control GPIO: https://learn.adafruit.com/circuitpython-on-any-computer-with-ft232h/gpio

BME680 sensor: https://learn.pimoroni.com/article/getting-started-with-bme680-breakout
Library: https://github.com/adafruit/Adafruit_CircuitPython_BME680

## Run test scripts
Example:
```bash
source env.sh
python test-ft232h-gpio.py
```

## Run the device service

Install dependencies:
```
sudo snap install edgexfoundry --edge
```

Get a token from edgexfoundry:
```
./add-addon-service.sh
```

Go to `device-service` and configure the devices. Then build and run:
```
go run . --overwrite
```

Get sensor values:
```
curl -X 'GET' 'http://localhost:59882/api/v2/device/name/GasSensor/ReadAll' | jq
```

Set GPIO output:
```
curl -X 'PUT' -d '{"State": true}'  'http://localhost:59882/api/v2/device/name/Fan/State' | jq
curl -X 'PUT' -d '{"State": false}'  'http://localhost:59882/api/v2/device/name/Fan/State' | jq
```

Delete devices and profiles:
```
# Gas sensor
curl -X 'DELETE'   'http://localhost:59881/api/v2/device/name/GasSensor' && curl -X 'DELETE'   'http://localhost:59881/api/v2/deviceprofile/name/BME680'

# GPIO
curl -X 'DELETE'   'http://localhost:59881/api/v2/device/name/Fan' && curl -X 'DELETE'   'http://localhost:59881/api/v2/deviceprofile/name/FanController' 
```
