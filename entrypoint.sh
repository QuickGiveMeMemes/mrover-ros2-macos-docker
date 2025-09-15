#!/bin/bash

# export DISPLAY=:1
# export LIBGL_ALWAYS_SOFTWARE=1
# export WGPU_BACKEND=CPU   # force software backend

# Xvfb :1 -screen 0 1920x1080x24 &
# fluxbox &
# x11vnc -display :1 -nopw -forever &
# sleep 2
source /opt/ros/humble/setup.bash
source /home/mrover/ros2_ws/install/setup.bash
exec "$@"  # runs whatever command is passed, keeps it as PID 1
