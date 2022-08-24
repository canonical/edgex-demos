import adafruit_bme680
import board
import json
import argparse
from ast import literal_eval

# Parse CLI args
parser = argparse.ArgumentParser()
parser.add_argument("-i2c", help="Set I2C Address", type=str, default='0x77')
args = parser.parse_args()
i2cAddr = literal_eval(args.i2c)

# Create sensor object, communicating over the board's default I2C bus
i2c = board.I2C()   # uses board.SCL and board.SDA
bme680 = adafruit_bme680.Adafruit_BME680_I2C(i2c, address=i2cAddr)

# change this to match the location's pressure (hPa) at sea level
# bme680.sea_level_pressure = 1013.25

data = {
    "temperature": bme680.temperature,
    "humidity": bme680.relative_humidity,
    # "pressure": bme680.pressure,
    # "gas": bme680.gas
}
print(json.dumps(data))
