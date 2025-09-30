#!/usr/bin/env python3

# python linear algebra library
import numpy as np

# library for interacting with ROS and TF tree
import rclpy
from rclpy.node import Node
import rclpy.time
import tf2_ros

# ROS message types we need to use
from sensor_msgs.msg import NavSatFix, Imu

# SE3 library for handling poses and TF tree
from util.SE3 import SE3
from util.SO3 import SO3


class Localization(Node):
    pose: SE3
    REFERENCE_COORDINATES = np.array([38.4225202, -110.7844653])

    def __init__(self):
        super().__init__("localization")
        # create subscribers for GPS and IMU data, linking them to our callback functions
        self.gps_subscription = self.create_subscription(NavSatFix, "/gps/fix", self.gps_callback, 10)
        self.imu_subscription = self.create_subscription(Imu, "/imu/data_raw", self.imu_callback, 10)

        # create a transform broadcaster for publishing to the TF tree
        self.tf_broadcaster = tf2_ros.TransformBroadcaster(self)

        # initialize pose to all zeros
        self.pose = SE3()

    def gps_callback(self, msg: NavSatFix):
        """
        This function will be called every time this node receives a NavSatFix message
        on the /gps topic. It should read the GPS location from the given NavSatFix message,
        convert it to cartesian coordinates, store that value in `self.pose`, then publish
        that pose to the TF tree.
        """
        spher_coord = np.array([msg.latitude, msg.longitude])
        cart_coord = Localization.spherical_to_cartesian(spher_coord, self.REFERENCE_COORDINATES)

        self.pose = SE3(cart_coord.copy(), self.pose.rotation)
        self.pose.publish_to_tf_tree(self.tf_broadcaster,"map", "rover_base_link", rclpy.time.Time.from_msg(msg.header.stamp))

    def imu_callback(self, msg: Imu):
        """
        This function will be called every time this node receives an Imu message
        on the /imu topic. It should read the orientation data from the given Imu message,
        store that value in `self.pose`, then publish that pose to the TF tree.
        """
        q = msg.orientation
        orientation = np.array([q.x, q.y, q.z, q.w])
        self.pose = SE3(self.pose.position, SO3(orientation))
        self.pose.publish_to_tf_tree(self.tf_broadcaster, "map", "rover_base_link", rclpy.time.Time.from_msg(msg.header.stamp))
        

    @staticmethod
    def spherical_to_cartesian(spherical_coord: np.ndarray, reference_coord: np.ndarray) -> np.ndarray:
        """
        This is a utility function that should convert spherical (latitude, longitude)
        coordinates into cartesian (x, y, z) coordinates using the specified reference point
        as the center of the tangent plane used for approximation.
        :param spherical_coord: the spherical coordinate to convert,
                                given as a numpy array [latitude, longitude]
        :param reference_coord: the reference coordinate to use for conversion,
                                given as a numpy array [latitude, longitude]
        :returns: the approximated cartesian coordinates in meters, given as a numpy array [x, y, z]
        """
        R = 6371000

        lat = np.deg2rad(spherical_coord[0])
        long = np.deg2rad(spherical_coord[1])
        lat_0 = np.deg2rad(reference_coord[0])
        long_0 = np.deg2rad(reference_coord[1])

        x = R * (lat - lat_0);
        y = R * (long - long_0) * np.cos(lat_0);

        return np.array([y, x, 0]) # idk why this works



def main():
    # initialize the node
    rclpy.init()

    # create and start our localization system
    localization = Localization()

    # let the callback functions run asynchronously in the background
    rclpy.spin(localization)

    rclpy.shutdown()


if __name__ == "__main__":
    main()
