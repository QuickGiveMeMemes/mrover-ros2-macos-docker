import numpy as np

from context import Context
from drive import get_drive_command
from state_machine.state import State
from tag_seek import TagSeekState


class DriveState(State):
    def on_enter(self, context) -> None:
        pass

    def on_exit(self, context) -> None:
        pass

    def on_loop(self, context : Context) -> State:
        target = np.array([8.0, 1.5, 0.0])

        pose = context.rover.get_pose()
        context.node.get_logger().debug(f"Debug message: pose = {pose}")
        if pose is None:
            return self
        # TODO: get the rover's pose, if it doesn't exist stay in DriveState (return self)

        command = get_drive_command(target, pose, 0.7, 0.2)

        # TODO: get the drive command and completion status based on target and pose
        # (HINT: use get_drive_command(), with completion_thresh set to 0.7 and turn_in_place_thresh set to 0.2)

        if command[1]:
            return TagSeekState()

        # TODO: if we are finished getting to the target, go to TagSeekState

        context.rover.send_drive_command(command[0])

        # TODO: send the drive command to the rover

        return self

        # TODO: tell state machine to stay in the DriveState by returning self
