import time
import board
import digitalio

led = digitalio.DigitalInOut(board.C0)
led.direction = digitalio.Direction.OUTPUT

while True:
    led.value = True
    print("on")
    time.sleep(1.0)
    led.value = False
    print("off")
    time.sleep(1.0)
