FROM ghcr.io/sloretz/ros:humble-desktop-full
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
RUN mkdir -p /home/mrover/tmp/mrover
COPY  --chown=mrover:mrover . /home/mrover/tmp/mrover
RUN git config --global --add safe.directory /home/mrover/tmp/mrover

WORKDIR  /home/mrover/tmp/mrover

# RUN git remote add origin git@github.com:QuickGiveMeMemes/mrover-ros2-macos-docker.git
# RUN --mount=type=ssh git remote set-url origin git@github.com:QuickGiveMeMemes/mrover-ros2-macos-docker.git
# RUN --mount=type=ssh git lfs pull --include="urdf/**"

# RUN git config --global credential.helper store
# RUN echo "https://${USERNAME}:${PAT}@github.com" > /home/mrover/.git-credentials
# RUN git remote set-url origin https://github.com/QuickGiveMeMemes/mrover-ros2-macos-docker.git
# RUN git lfs pull --include="urdf/**"


WORKDIR /

RUN mkdir -p /home/mrover/ros2_ws/src/mrover

COPY --chown=mrover:mrover . /home/mrover/ros2_ws/src/mrover
RUN cp -r /home/mrover/tmp/mrover/urdf /home/mrover/ros2_ws/src/mrover/urdf
RUN rm -rf /home/mrover/tmp/mrover
# COPY --chown=mrover:mrover ./.git /home/mrover/ros2_ws/src/mrover/


WORKDIR /home/mrover/ros2_ws/src/mrover
# RUN git lfs pull --include="urdf/**"

# RUN git lfs pull -I pkg/libdawn-dev.deb pkg/libmanif-dev.deb

# RUN ./ansible.sh ci.yml  --become --become-user=root

# RUN colcon build --symlink-install --packages-skip-by-dep python_qt_binding



# # Defines the APT packages that need to be installed
# # rosdep is called from Ansible to install them
# # ADD --chown=mrover:mrover ./package.xml .
# # # Defines the Python packages that need to be installed
# # # pip is called from Ansible to install them
# # ADD --chown=mrover:mrover ./pyproject.toml ./README.md .
# # ADD --chown=mrover:mrover ./mrover ./mrover
# # # Copy over all Ansible files
# # ADD --chown=mrover:mrover ./ansible ./ansible
# # ADD --chown=mrover:mrover ./ansible.sh .
# # ADD --chown=mrover:mrover ./pkg ./pkg
# # RUN sudo dpkg --add-architecture arm64
# # RUN git lfs pull -I pkg/libdawn-dev.deb pkg/libmanif-dev.deb
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
