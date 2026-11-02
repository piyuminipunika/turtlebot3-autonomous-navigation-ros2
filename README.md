# Autonomous Indoor Robot Navigation Using ROS 2

## Project Overview

This project demonstrates autonomous indoor mapping,
localization, and navigation using TurtleBot3 Waffle Pi
in a simulated house environment.

## Technologies

- Ubuntu 24.04
- ROS 2 Jazzy
- Gazebo Harmonic
- TurtleBot3 Waffle Pi
- SLAM Toolbox
- Frontier Exploration
- AMCL
- Nav2
- RViz2
- Python

## Main Features

- Autonomous SLAM mapping
- Frontier-based exploration
- Saved occupancy grid map
- AMCL localization
- Autonomous room-to-room navigation
- Named destination navigation
- Interactive text commands
- Automated system startup

## Available Destinations

- Room 1
- Room 2
- Room 3
- Room 4
- Living Room

## Start Navigation System

```bash
~/autonomous_robot/scripts/start_robot.sh

##Frontier Exploration

## Autonomous Frontier Exploration

This project uses an existing open-source Frontier Exploration implementation to enable autonomous mapping in the TurtleBot3 House environment.

### How It Works

1. SLAM Toolbox generates an occupancy grid map using LiDAR and odometry data.
2. The Frontier Exploration algorithm identifies boundaries between explored free space and unexplored regions.
3. The algorithm selects a suitable exploration goal.
4. Nav2 navigates the robot toward the selected goal.
5. The map is updated as the robot explores new areas.
6. This process repeats to progressively explore the environment.

### Original Implementation and Attribution

**Original Repository:**  
https://github.com/mertgulerx/frontier_exploration_ros2

**Fork Used in This Project:**  
https://github.com/wangfei-tech/frontier-exploration-ros2

**ROS 2 Package:** `frontier_exploration_ros2`

The Frontier Exploration algorithm was not implemented from scratch in this project. An existing open-source implementation was integrated with SLAM Toolbox, Nav2, and TurtleBot3.

### My  Contribution

My  work focuses on integrating and configuring autonomous exploration, mapping, localization, and navigation within a ROS 2 simulation environment.

Custom components include Python-based named-location navigation, interactive text commands, semantic room coordinates, Nav2 configuration, and automated system startup scripts.
