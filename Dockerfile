FROM openvino/ubuntu18_data_dev:latest

USER root

# Dependencies for OpenVINO
RUN if [ -f /opt/intel/openvino/install_dependencies/install_openvino_dependencies.sh ]; then \
       /opt/intel/openvino/install_dependencies/install_openvino_dependencies.sh -y;\
    fi  

# Dependencies for OpenVINO mode optimizer
RUN if [ -f /opt/intel/openvino/deployment_tools/model_optimizer/install_prerequisites/install_prerequisites.sh ]; then \
       /opt/intel/openvino/deployment_tools/model_optimizer/install_prerequisites/install_prerequisites.sh;\
    fi 

# Download object detection YOLO model
RUN cd /opt/intel/openvino/deployment_tools/open_model_zoo/tools/downloader \
	&& python3 downloader.py --name yolo-v2-tiny-ava-0001

RUN apt-get update && apt-get install -y --no-install-recommends apt-utils
RUN apt-get update && apt-get install -y jq

COPY start-object-detection.sh .

ENV DISPLAY=:0
ENV DETECTION_MODEL=/opt/intel/openvino/deployment_tools/open_model_zoo/tools/downloader/intel/yolo-v2-tiny-ava-0001/FP32/yolo-v2-tiny-ava-0001.xml
ENV DETECTION_MODEL_PROC=/opt/intel/openvino/data_processing/dl_streamer/samples/model_proc/intel/object_detection/yolo-v2-tiny-ava-0001.json
ENV CORE_COMMAND=http://localhost:59882

ENTRYPOINT ["./start-object-detection.sh"]
