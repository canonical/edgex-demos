
from adafruit_bme680 import Adafruit_BME680_I2C
import time
import board
import digitalio


# Create sensor object, communicating over the board's default I2C bus
i2c = board.I2C()   # uses board.SCL and board.SDA
bme680 = Adafruit_BME680_I2C(i2c, address=0x76)

led = digitalio.DigitalInOut(board.C0)
led.direction = digitalio.Direction.OUTPUT

# change this to match the location's pressure (hPa) at sea level
bme680.sea_level_pressure = 1013.25

while True:
    led.value = True
    print("\nTemperature: %0.1f C" % bme680.temperature)
    print("Gas: %d ohm" % bme680.gas)
    print("Humidity: %0.1f %%" % bme680.relative_humidity)
    print("Pressure: %0.3f hPa" % bme680.pressure)
    print("Altitude = %0.2f meters" % bme680.altitude)
    time.sleep(2)

    led.value = False
    time.sleep(1)
