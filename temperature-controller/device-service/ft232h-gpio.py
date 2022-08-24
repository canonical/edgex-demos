import board
import digitalio


import argparse

# Parse CLI args
parser = argparse.ArgumentParser()
parser.add_argument("-pin", help="GPIO pin number", type=str)
parser.add_argument("-value", help="GPIO pin output value", type=str)
args = parser.parse_args()
pin = args.pin
value = args.value == 'true'

led = digitalio.DigitalInOut(getattr(board, pin))
led.direction = digitalio.Direction.OUTPUT

led.value = value
