#!/bin/bash

# Function to keep the Xvfb running
function keepUpScreen() {
    echo "Running keepUpScreen()"
    while true; do
        sleep 1
        if [ -z "$(pidof Xvfb)" ]; then
            echo "Xvfb is not running. Starting Xvfb..."
            Xvfb :99 -screen 0 1600x900x16 &
        fi
    done
}

# Configure and start Xvfb
export DISPLAY=:99.0
rm -f /tmp/.X99-lock &>/dev/null # remove the lock file for X server display number 99
Xvfb :99 -screen 0 1600x900x16 &

# Start xfce
startxfce4 &

# Start x11vnc without a password, accessible only from localhost
x11vnc -display :99 -rfbport 5900 -nopw -forever &

# Keep Xvfb running
keepUpScreen &

# Wait for any background processes to finish
wait $!

# Execute commands passed to the Docker container
exec "$@"
