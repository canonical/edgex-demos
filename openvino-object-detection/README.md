# openvino-object-detection
Demo resources for Object Detection with EdgeX and OpenVINO.

Refer to the wiki for instructions on setting up the demo:
https://github.com/canonical/edgex-demos/wiki/Object-Detection-with-EdgeX-and-OpenVINO

### Build custom edgex-openvino-object-detection Docker image
This repository folder contains the Dockerfile to build a docker image.
#### How to build:
Go to the openvino-object-detection folder with the Dockerfile and run:
```bash
sudo docker build . --tag edgex-openvino-object-detection
```
#### How to run:
```bash
sudo docker run --network=host --name=openvino --restart=unless-stopped --detach edgex-openvino-object-detection:latest
```
- `--network`: connect a container to a network
- `--name`: assign a name to the container
- `--restart=unless-stopped`: restart the container unless it is explicitly stopped or Docker itself is stopped or restarted
- `--detach`: run container in background and print container ID

### License
This Dockerfile contains third-party components with different licenses.  
If you are distributing the container as a whole, then you are responsible for license compliance for all of the software it contains.
