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

# Add library paths
# The list is taken from docker container's shell envirinment, e.g.:
# docker build -t openvino .
# docker run --entrypoint=env -it --rm openvino | grep LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=/opt/intel/openvino/opt/intel/mediasdk/lib64/:/opt/intel/openvino/data_processing/dl_streamer/lib:/opt/intel/openvino/data_processing/gstreamer/lib:/opt/intel/openvino/opencv/lib:/opt/intel/openvino/deployment_tools/ngraph/lib:/opt/intel/openvino/deployment_tools/inference_engine/external/tbb/lib::/opt/intel/openvino/deployment_tools/inference_engine/external/hddl/lib:/opt/intel/openvino/deployment_tools/inference_engine/external/omp/lib:/opt/intel/openvino/deployment_tools/inference_engine/external/gna/lib:/opt/intel/openvino/deployment_tools/inference_engine/external/mkltiny_lnx/lib:/opt/intel/openvino/deployment_tools/inference_engine/lib/intel64

ENTRYPOINT ["./start-object-detection.sh"]
