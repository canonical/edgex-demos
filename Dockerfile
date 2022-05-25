FROM openvino/ubuntu18_data_dev:latest

USER root

ENV DISPLAY=$DISPLAY
ENV DETECTION_MODEL=/opt/intel/openvino/deployment_tools/open_model_zoo/tools/downloader/intel/yolo-v2-tiny-ava-0001/FP32/yolo-v2-tiny-ava-0001.xml
ENV DETECTION_MODEL_PROC=/opt/intel/openvino/data_processing/dl_streamer/samples/model_proc/intel/object_detection/yolo-v2-tiny-ava-0001.json

# Dependencies for OpenVINO
RUN if [ -f /opt/intel/openvino/install_dependencies/install_openvino_dependencies.sh ]; then \
       /opt/intel/openvino/install_dependencies/install_openvino_dependencies.sh -y;\
    fi  

# Dependencies for OpenVINO mode optimizer
RUN if [ -f /opt/intel/openvino/deployment_tools/model_optimizer/install_prerequisites/install_prerequisites.sh ]; then \
       /opt/intel/openvino/deployment_tools/model_optimizer/install_prerequisites/install_prerequisites.sh;\
    fi 

# Download obeject detection YOLO model
RUN cd /opt/intel/openvino/deployment_tools/open_model_zoo/tools/downloader \
	&& python3 downloader.py --name yolo-v2-tiny-ava-0001
  
