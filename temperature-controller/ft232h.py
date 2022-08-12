import time
import board
import digitalio

led = digitalio.DigitalInOut(board.D4)
led.direction = digitalio.Direction.OUTPUT

while True:
    led.value = True
    time.sleep(0.5)
    led.value = False
    time.sleep(0.5)
