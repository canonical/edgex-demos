#!/bin/python

import adafruit_bme680
import time
import board
import json


# Create sensor object, communicating over the board's default I2C bus
i2c = board.I2C()   # uses board.SCL and board.SDA
bme680 = adafruit_bme680.Adafruit_BME680_I2C(i2c, address=0x76)

# change this to match the location's pressure (hPa) at sea level
bme680.sea_level_pressure = 1013.25

data = {
    "temperature": bme680.temperature,
    "humidity": bme680.relative_humidity,
    "pressure": bme680.pressure,
    "gas": bme680.gas
}
print(json.dumps(data))
