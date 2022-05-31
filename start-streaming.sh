#!/bin/bash -e

echo "Starting device camera usb streaming"

curl -X PUT -d '{
    "StartStreaming": {
      "InputFps": "5",
      "InputImageSize": "320x240",
      "OutputVideoQuality": "31",
      "OutputImageSize": "320x240"
    }
}' http://localhost:59882/api/v2/device/name/example-camera/StartStreaming

