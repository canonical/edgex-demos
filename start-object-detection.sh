#!/bin/bash -e

echo "Environment Variables:"
env

echo "Querying core command for the rtsp URL"

CURL_RES=$(curl --show-error --silent --write-out "%{http_code}" \
    --request GET $CORE_COMMAND/api/v2/device/name/example-camera/StreamURI)
HTTP_CODE="${CURL_RES:${#CURL_RES}-3}"

if [ $HTTP_CODE -ne 200 ] ; then
    echo "Error on querying core command for the rtsp URL:"
	# todo: check if body isn't empty  
	BODY="${CURL_RES:0:${#CURL_RES}-3}"
	echo $BODY
    exit 1
fi

if [ ${#CURL_RES} -eq 3 ]; then
	echo "Error on unexpected http response with empty body"
	exit 1
else
	BODY="${CURL_RES:0:${#CURL_RES}-3}"
fi

RTSP_URL=$(echo $BODY | jq -r '.event.readings | .[] | .value')
echo "RTSP URL of EdgeX Device Camera: $RTSP_URL"

echo "Starting object detection demo"
source ./data_processing/dl_streamer/bin/setupvars.sh
exec gst-launch-1.0 \
	urisourcebin uri=$RTSP_URL ! decodebin ! \
	gvadetect model=${DETECTION_MODEL} model_proc=${DETECTION_MODEL_PROC} device=CPU ! queue ! \
	gvametaconvert format=json ! queue ! \
	gvametapublish address=localhost:1883 method=mqtt topic=openvino/MQTT-test-device/prediction qos=true ! queue ! \
	gvawatermark ! videoconvert ! fpsdisplaysink video-sink=autovideosink sync=false


