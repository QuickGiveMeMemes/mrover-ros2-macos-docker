FROM arm64v8/ros:humble-ros-base-jammy

# Builds mrover source code and ROS2 in a separate mrover user on the image.

# DEBIAN_FRONTEND=noninteractive prevents apt from asking for user input
# software-properties-common is needed for apt-add-repository
# sudo is needed for ansible since it escalates from a normal user to root
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/depot_tools:${PATH}"

ARG PAT
ARG USERNAME

RUN apt-get update -y && apt-get install software-properties-common sudo -y
RUN apt-add-repository ppa:ansible/ansible -y && apt-get install -y git git-lfs ansible

RUN useradd --create-home --groups sudo --shell /bin/zsh mrover
# Give mrover user sudo access with no password
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers


# Installing dependencies
RUN sudo apt-get install    libxrandr-dev libxinerama-dev libxcursor-dev mesa-common-dev \
                            libx11-xcb-dev libeigen3-dev pkg-config git cmake build-essential \
                            python3-pip python3-setuptools xvfb fluxbox x11vnc novnc websockify \
                            mesa-vulkan-drivers vulkan-tools -y

RUN export XDG_RUNTIME_DIR=/tmp/runtime-root

RUN apt-get update \ 
    && python3 -m pip install --upgrade pip \
    && python3 -m pip install -U colcon-common-extensions


# Setting up mrover user within docker

WORKDIR /
RUN git lfs install --system
USER mrover
# Copy directory over into temp dir for Git LFS (so the file pointers are preserved on the local system)
# Unpacked files are later copied over into main mrover directory.
RUN mkdir -p /home/mrover/ros2_ws/src/mrover
RUN git config --global --add safe.directory /home/mrover/ros2_ws/src/mrover

WORKDIR  /home/mrover/ros2_ws/src/mrover
COPY --chown=mrover:mrover . /home/mrover/ros2_ws/src/mrover

RUN git config --global credential.helper store
RUN echo "https://${USERNAME}:${PAT}@github.com" > /home/mrover/.git-credentials
RUN git remote set-url origin https://github.com/QuickGiveMeMemes/mrover-ros2-macos-docker.git
RUN git lfs pull --include="urdf/**"

USER root
RUN ./ansible.sh ci.yml

USER mrover
WORKDIR /home/mrover/ros2_ws/src/mrover
RUN git submodule update --init
RUN ./scripts/build_dawn.sh
RUN ./scripts/build_manifpy.sh

USER root
RUN apt-get purge ansible -y && apt-get autoremove -y
# Remove apt cache to free up space in the image
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

RUN echo "source /opt/ros/humble/setup.bash" >> /home/mrover/.bashrc && \
    echo "source /home/mrover/ros2_ws/install/setup.bash" >> /home/mrover/.bashrc
RUN /bin/bash -c "source /opt/ros/humble/setup.bash && ./build.sh"

USER mrover
WORKDIR /home/mrover/ros2_ws/src/mrover

RUN chmod +x entrypoint.sh
