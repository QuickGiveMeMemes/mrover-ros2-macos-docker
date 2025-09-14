FROM ghcr.io/sloretz/ros:humble-desktop-full
# DEBIAN_FRONTEND=noninteractive prevents apt from asking for user input
# software-properties-common is needed for apt-add-repository
# sudo is needed for ansible since it escalates from a normal user to root
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/depot_tools:${PATH}"

RUN apt-get update -y && apt-get install software-properties-common sudo -y
RUN apt-add-repository ppa:ansible/ansible -y && apt-get install -y git git-lfs ansible

RUN useradd --create-home --groups sudo --shell /bin/zsh mrover
# Give mrover user sudo access with no password
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers


# Installing dependencies and modern Cmake for libdawn and libmanif
RUN sudo apt-get install    libxrandr-dev libxinerama-dev libxcursor-dev mesa-common-dev \
                            libx11-xcb-dev libeigen3-dev pkg-config git cmake build-essential \
                             python3-pip python3-setuptools xvfb fluxbox x11vnc novnc websockify -y


# RUN apt-get update && apt-get install -y wget gpg software-properties-common && \
#     wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg && \
#     echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/kitware.list && \
#     apt-get update && \
#     apt-get install -y cmake


# Installing colcon

RUN apt-get update \ 
    && python3 -m pip install --upgrade pip \
    && python3 -m pip install -U colcon-common-extensions

# # Installing libmanif
# WORKDIR /opt/
# RUN git clone https://github.com/artivis/manif.git

# WORKDIR /opt/manif
# RUN mkdir build
# RUN cmake . -DCMAKE_BUILD_TYPE=Release
# RUN make -j$(nproc)
# RUN sudo make install

# # Installing libdawn
# WORKDIR /opt/
# RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git /opt/depot_tools
# RUN git clone https://dawn.googlesource.com/dawn

# WORKDIR /opt/dawn
# RUN cp scripts/standalone.gclient .gclient
# RUN gclient sync


# Setting up docker copy



WORKDIR /
USER mrover

RUN mkdir -p /home/mrover/ros2_ws/src/mrover

COPY --chown=mrover:mrover . /home/mrover/ros2_ws/src/mrover
# COPY --chown=mrover:mrover ./.git /home/mrover/ros2_ws/src/mrover/


WORKDIR /home/mrover/ros2_ws/src/mrover

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
