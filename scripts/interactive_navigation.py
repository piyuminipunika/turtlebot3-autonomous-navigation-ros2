#!/usr/bin/env python3

import sys
from pathlib import Path

import yaml

sys.path.insert(
    0,
    str(Path.home() / "autonomous_robot/scripts")
)

import rclpy
from go_to_room import RoomNavigator


ROOM_FILE = (
    Path.home()
    / "autonomous_robot/config/room_locations.yaml"
)


def main():

    with open(ROOM_FILE) as f:
        rooms = yaml.safe_load(f)["rooms"]

    rclpy.init()
    navigator = RoomNavigator()

    print("\n🤖 TURTLEBOT3 NAVIGATION ASSISTANT")
    print("----------------------------------")
    print("Available locations:")

    for room in rooms.values():
        print(f"  - {room['name']}")

    print("\nType 'exit' to quit.")

    try:
        while True:

            command = input("\nYou: ").strip().lower()

            if command in ("exit", "quit"):
                print("🤖 Goodbye!")
                break

            # Accept commands like:
            # "room 1", "go to room 1", "living room"
            if command.startswith("go to "):
                command = command[6:]

            selected = command.replace(" ", "_")

            if selected not in rooms:
                print("❌ Unknown location. Try again.")
                continue

            navigator.go_to_room(rooms[selected])

    except KeyboardInterrupt:
        print("\n🤖 Navigation assistant stopped.")

    finally:
        navigator.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
