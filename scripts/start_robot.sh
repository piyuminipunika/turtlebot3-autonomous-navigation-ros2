#!/bin/bash

set -e

source /opt/ros/jazzy/setup.bash
source "$HOME/turtlebot3_ws/install/setup.bash"

export TURTLEBOT3_MODEL=waffle_pi

MAP="$HOME/autonomous_robot/maps/house_map_final.yaml"
PARAMS="$HOME/autonomous_robot/config/house_nav2.yaml"

RVIZ_CONFIG="/opt/ros/jazzy/share/nav2_bringup/rviz/nav2_default_view.rviz"

COMMON="source /opt/ros/jazzy/setup.bash; source $HOME/turtlebot3_ws/install/setup.bash; export TURTLEBOT3_MODEL=waffle_pi"

echo "=========================================="
echo " TURTLEBOT3 AUTONOMOUS NAVIGATION SYSTEM"
echo "=========================================="

# Check required files
for file in "$MAP" "$PARAMS" "$RVIZ_CONFIG"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Missing file: $file"
        exit 1
    fi
done

# Check GUI terminal
if ! command -v gnome-terminal >/dev/null 2>&1; then
    echo "ERROR: gnome-terminal is not installed."
    exit 1
fi

if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    echo "ERROR: No graphical desktop session detected."
    exit 1
fi

# Open a new terminal for each ROS component
launch_terminal() {
    local title="$1"
    local command="$2"

    gnome-terminal \
        --title="$title" \
        -- bash -lc "$COMMON; $command; exec bash"
}

# Check Gazebo model
robot_exists() {
    timeout 5 gz model --list 2>/dev/null |
        grep -Eq '^[[:space:]]*-[[:space:]]*waffle_pi[[:space:]]*$'
}

# Check ROS lifecycle
node_active() {
    timeout 5 ros2 lifecycle get "/$1" 2>/dev/null |
        grep -q 'active \[3\]'
}

# Stop if previous simulation is running
if timeout 5 gz model --list >/dev/null 2>&1; then
    echo ""
    echo "ERROR: A Gazebo world is already running."
    echo "Close the old simulation before starting again."
    exit 1
fi

for node in /amcl /map_server /controller_server /bt_navigator; do
    if ros2 node list 2>/dev/null | grep -qx "$node"; then
        echo "ERROR: Existing ROS node detected: $node"
        echo "Stop the previous ROS system first."
        exit 1
    fi
done

# =========================================
# 1. START GAZEBO
# =========================================

echo ""
echo "[1/5] Starting Gazebo House..."

launch_terminal "1 - Gazebo House" \
    "ros2 launch turtlebot3_gazebo turtlebot3_house.launch.py x_pose:=-3.0 y_pose:=2.0"

echo "Checking robot spawn..."

ROBOT_READY=0

for i in {1..45}; do
    if robot_exists; then
        ROBOT_READY=1
        break
    fi
    sleep 2
done

# =========================================
# 2. FIX MISSING ROBOT
# =========================================

if [ "$ROBOT_READY" -eq 0 ]; then

    echo ""
    echo "Robot missing. Starting standalone spawn..."

    launch_terminal "2 - Robot Spawn" \
        "ros2 launch turtlebot3_gazebo spawn_turtlebot3.launch.py x_pose:=-3.0 y_pose:=2.0"

    for i in {1..35}; do
        if robot_exists; then
            ROBOT_READY=1
            break
        fi
        sleep 2
    done
fi

if [ "$ROBOT_READY" -eq 0 ]; then
    echo "ERROR: waffle_pi did not spawn."
    echo "Check Gazebo and Robot Spawn terminal messages."
    exit 1
fi

echo "SUCCESS: waffle_pi detected in Gazebo!"

# =========================================
# 3. CHECK LIDAR
# =========================================

echo ""
echo "[2/5] Checking LiDAR data..."

SCAN_READY=0

for i in {1..25}; do
    if timeout 6 ros2 topic echo \
        /scan sensor_msgs/msg/LaserScan \
        --once \
        --qos-reliability best_effort \
        >/dev/null 2>&1; then
        SCAN_READY=1
        break
    fi
    sleep 2
done

if [ "$SCAN_READY" -eq 0 ]; then
    echo "ERROR: No LiDAR data."
    echo "Check Gazebo robot and ROS-Gazebo bridge."
    exit 1
fi

echo "SUCCESS: LiDAR data received!"

# =========================================
# 4. START MAP SERVER + AMCL
# =========================================

echo ""
echo "[3/5] Starting Map Server and AMCL..."

launch_terminal "3 - AMCL Localization" \
    "ros2 launch nav2_bringup localization_launch.py map:=$MAP params_file:=$PARAMS use_sim_time:=true use_composition:=False autostart:=true"

AMCL_READY=0

for i in {1..60}; do
    if node_active map_server && node_active amcl; then
        AMCL_READY=1
        break
    fi
    sleep 2
done

if [ "$AMCL_READY" -eq 0 ]; then
    echo "ERROR: AMCL or Map Server failed to activate."
    exit 1
fi

echo "SUCCESS: Map Server and AMCL active!"

# =========================================
# 5. START NAV2
# =========================================

echo ""
echo "[4/5] Starting Nav2..."

launch_terminal "4 - Nav2 Navigation" \
    "ros2 launch nav2_bringup navigation_launch.py params_file:=$PARAMS use_sim_time:=true use_composition:=False autostart:=true"

NAV_READY=0

for i in {1..60}; do
    if node_active controller_server &&
       node_active planner_server &&
       node_active bt_navigator; then
        NAV_READY=1
        break
    fi
    sleep 2
done

if [ "$NAV_READY" -eq 0 ]; then
    echo "ERROR: Nav2 failed to activate."
    exit 1
fi

echo "SUCCESS: Nav2 active!"

# =========================================
# 6. START RVIZ
# =========================================

echo ""
echo "[5/5] Opening RViz2..."

launch_terminal "5 - RViz2" \
    "rviz2 -d $RVIZ_CONFIG --ros-args -p use_sim_time:=true"

RVIZ_READY=0

for i in {1..20}; do
    if pgrep -x rviz2 >/dev/null 2>&1; then
        RVIZ_READY=1
        break
    fi
    sleep 1
done

# Fallback if RViz process did not launch
if [ "$RVIZ_READY" -eq 0 ]; then
    echo "Retrying RViz directly..."

    rviz2 -d "$RVIZ_CONFIG" \
        --ros-args -p use_sim_time:=true \
        > "$HOME/autonomous_robot/rviz_startup.log" 2>&1 &

    sleep 5

    if pgrep -x rviz2 >/dev/null 2>&1; then
        RVIZ_READY=1
    fi
fi

if [ "$RVIZ_READY" -eq 0 ]; then
    echo "WARNING: RViz did not start."
    echo "Check ~/autonomous_robot/rviz_startup.log"
else
    echo "SUCCESS: RViz process detected!"
fi

echo ""
echo "=========================================="
echo " STARTUP CHECKS COMPLETE"
echo "=========================================="
echo "Gazebo Robot : OK"
echo "LiDAR        : OK"
echo "Map Server   : ACTIVE"
echo "AMCL         : ACTIVE"
echo "Nav2         : ACTIVE"

if [ "$RVIZ_READY" -eq 1 ]; then
    echo "RViz         : PROCESS RUNNING"
else
    echo "RViz         : CHECK REQUIRED"
fi

echo ""
echo "Verify the robot pose in RViz before navigation."
echo "=========================================="
