#!/usr/bin/env python3

import sys
import math
from pathlib import Path

import yaml
import rclpy

from rclpy.node import Node
from rclpy.action import ActionClient

from nav2_msgs.action import NavigateToPose
from geometry_msgs.msg import PoseStamped
from action_msgs.msg import GoalStatus


ROOM_FILE = (
    Path.home()
    / "autonomous_robot/config/room_locations.yaml"
)


class RoomNavigator(Node):

    def __init__(self):
        super().__init__("room_navigator")

        self.action_client = ActionClient(
            self,
            NavigateToPose,
            "navigate_to_pose"
        )

    def go_to_room(self, room):

        x = float(room["x"])
        y = float(room["y"])
        yaw = float(room.get("yaw", 0.0))

        print(f"\n🎯 Destination: {room['name']}")
        print(f"📍 X: {x:.2f}, Y: {y:.2f}")

        print("⏳ Waiting for Nav2...")

        if not self.action_client.wait_for_server(
            timeout_sec=15.0
        ):
            print("❌ Nav2 action server unavailable!")
            return False

        goal = NavigateToPose.Goal()

        pose = PoseStamped()

        pose.header.frame_id = room.get("frame_id", "map")
        pose.header.stamp = self.get_clock().now().to_msg()

        pose.pose.position.x = x
        pose.pose.position.y = y
        pose.pose.position.z = 0.0

        pose.pose.orientation.z = math.sin(yaw / 2.0)
        pose.pose.orientation.w = math.cos(yaw / 2.0)

        goal.pose = pose

        print("🚀 Sending navigation goal...")

        future = self.action_client.send_goal_async(goal)

        rclpy.spin_until_future_complete(self, future)

        goal_handle = future.result()

        if goal_handle is None or not goal_handle.accepted:
            print("❌ Navigation goal rejected!")
            return False

        print("✅ Goal accepted!")
        print("🤖 Robot is navigating...")

        result_future = goal_handle.get_result_async()

        rclpy.spin_until_future_complete(
            self,
            result_future
        )

        result = result_future.result()

        if result is None:
            print("❌ No navigation result received.")
            return False

        if result.status == GoalStatus.STATUS_SUCCEEDED:
            print(f"\n🎉 Reached {room['name']}!")
            return True

        print(f"❌ Navigation unsuccessful. Status: {result.status}")
        return False


def main():

    with open(ROOM_FILE, "r") as file:
        data = yaml.safe_load(file)

    rooms = data["rooms"]

    print("\n🏠 AVAILABLE LOCATIONS")
    print("------------------------")

    for key, room in rooms.items():
        print(f"{key} → {room['name']}")

    print("------------------------")

    if len(sys.argv) > 1:
        selected = sys.argv[1].strip().lower()
    else:
        selected = input("\nEnter location: ").strip().lower()

    selected = selected.replace(" ", "_")

    if selected not in rooms:
        print("❌ Unknown location!")
        return

    rclpy.init()

    navigator = RoomNavigator()

    try:
        navigator.go_to_room(rooms[selected])
    except KeyboardInterrupt:
        print("\nNavigation client interrupted.")
        print("Use RViz to cancel an active goal if necessary.")
    finally:
        navigator.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
