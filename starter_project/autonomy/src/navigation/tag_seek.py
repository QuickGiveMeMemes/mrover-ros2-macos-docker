from geometry_msgs.msg import Twist

from context import Context
from state_machine.state import State
from state import DoneState, FailState


class TagSeekState(State):
    def on_enter(self, context) -> None:
        pass

    def on_exit(self, context) -> None:
        pass

    def on_loop(self, context: Context) -> State:
        DISTANCE_TOLERANCE = 0.15
        ANUGLAR_TOLERANCE = .01 # In +/- percentage of camera FOV 
        GOAL_ANGLE = 0.5
        
        # TODO: get the tag's location and properties (HINT: use get_fid_data() from context.env)

        tag_data = context.env.get_fid_data()

        # TODO: if we don't have a tag: go to the FailState

        if tag_data is None:
            return FailState()

        # TODO: if we are within angular and distance tolerances: go to DoneState

        if tag_data.closeness_metric > DISTANCE_TOLERANCE and abs(tag_data.x_tag_center_pixel - GOAL_ANGLE) < ANUGLAR_TOLERANCE:
            return DoneState()

        # TODO: figure out the Twist command to be applied to move the rover closer to the tag

        cmd = Twist()
        if tag_data.closeness_metric < DISTANCE_TOLERANCE:
            cmd.linear.x = (0.16 - tag_data.closeness_metric) * 3.5
        if abs(tag_data.x_tag_center_pixel - GOAL_ANGLE) > ANUGLAR_TOLERANCE:
            cmd.angular.z = -(tag_data.x_tag_center_pixel - GOAL_ANGLE) * 1.25

        # TODO: send Twist command to rover

        context.rover.send_drive_command(cmd)
        return self

        # TODO: stay in the TagSeekState (with outcome "working")
