#!/bin/bash

# --- Configuration ---
# Path to the Wallpaper Engine workshop content folder
WALLPAPER_DIR="~/.steam/steam/steamapps/workshop/content/431960"
mpvpaper_options="--no-osc --no-osd-bar --no-input-default-bindings --really-quiet --loop-file=inf --no-audio --panscan=1 --no-resume-playback --vf-add=fps=20:round=near"

# Temporary directory for unpacking
TMP_DIR="/tmp/hyprpaper-we"

# --- Functions ---

# Function to write PID with lock protection
write_pid() {
    local pid=$1
    (
        flock -x 200
        echo $pid > "$PID_FILE"
        echo "New PID: $pid"
        # Verify PID file was created and readable
        if [ -f "$PID_FILE" ] && [ -r "$PID_FILE" ]; then
            echo "PID file created successfully at $PID_FILE"
            echo "Stored PID: $(cat "$PID_FILE")"
        else
            echo "Warning: Failed to create or read PID file"
        fi
    ) 200>"$LOCK_FILE"
}

# Function to read PID with lock protection
read_pid() {
    local pid=""
    if [ -f "$PID_FILE" ]; then
        (
            flock -s 200
            pid=$(cat "$PID_FILE" 2>/dev/null)
        )200>"$LOCKFILE"
    fi
    echo "$pid"
}
stopall() {
    declare -a pids
    declare -a locks
    readarray -t pids < <(find /tmp -maxdepth 1 -name "hyprpaper-we-*.pid" 2>/dev/null)
    readarray -t locks < <(find /tmp -maxdepth 1 -name "hyprpaper-we-*.lock" 2>/dev/null)
    
    for ((i=0; i<${#pids[@]}; i++))
    do
        PID_FILE="${pids[$i]}"
        LOCK_FILE="${locks[$i]}"
        
        # Extract the monitor name from PID file (what replaces the *)
        MONITOR="${PID_FILE#/tmp/hyprpaper-we-}"
        MONITOR="${MONITOR%.pid}"
        
        stop_wallpaper
    done
}
# Function to stop the current wallpaper
stop_wallpaper() {
    local killed=false
    
    # Debug: Check current state
    echo "[DEBUG] Checking PID file: $PID_FILE"
    
    # Try to use PID file first with lock protection
    if [ -f "$PID_FILE" ]; then
        local pid_to_kill=$(read_pid)
        
        if [ -z "$pid_to_kill" ]; then
            echo "[DEBUG] PID file exists but is empty"
            rm -f "$PID_FILE"
        else
            echo "[DEBUG] Found PID in file: $pid_to_kill"
            
            # More robust process check
            if kill -0 $pid_to_kill 2>/dev/null; then
                echo "Stopping wallpaper process with PID: $pid_to_kill"
                # Use SIGTERM first, then SIGKILL if needed
                kill $pid_to_kill
                sleep 0.5
                if kill -0 $pid_to_kill 2>/dev/null; then
                    echo "Process still running, sending SIGKILL..."
                    kill -9 $pid_to_kill
                fi
                rm -f "$PID_FILE"
                killed=true
            else
                echo "Process with PID $pid_to_kill not found. Removing stale PID file."
                rm -f "$PID_FILE"
            fi
        fi
    else
        echo "[DEBUG] PID file not found at $PID_FILE"
    fi
    
    # If PID file method failed, try to find processes by name
    if [ "$killed" = false ]; then
        echo "PID file not found or invalid. Searching for wallpaper processes..."
        
        # Find and kill mpvpaper processes
        local mpv_pids=$(pgrep -f "mpvpaper.*$MONITOR")
        if [ -n "$mpv_pids" ]; then
            echo "Found mpvpaper processes: $mpv_pids"
            for pid in $mpv_pids; do
                echo "Killing mpvpaper process: $pid"
                kill $pid
                sleep 0.2
                if kill -0 $pid 2>/dev/null; then
                    kill -9 $pid
                fi
                killed=true
            done
        fi
        
        # Find and kill web_viewer processes
        local web_pids=$(pgrep -f "web_viewer.py")
        if [ -n "$web_pids" ]; then
            echo "Found web_viewer processes: $web_pids"
            for pid in $web_pids; do
                echo "Killing web_viewer process: $pid"
                kill $pid
                sleep 0.2
                if kill -0 $pid 2>/dev/null; then
                    kill -9 $pid
                fi
                killed=true
            done
        fi
        
        if [ "$killed" = false ]; then
            echo "No active wallpaper processes found."
        fi
    fi
    
    # Ensure PID file is removed
    rm -f "$PID_FILE"
    rm -f "$LOCK_FILE"
}

# Function to set a new wallpaper
set_wallpaper() {
    # First, stop any previously running wallpaper
    stop_wallpaper

    local wallpaper_id=$1
    local wallpaper_path="$(eval echo $WALLPAPER_DIR)/$wallpaper_id"
    local pkg_file=""

    local project_json_path="$wallpaper_path/project.json"
    if [ ! -f "$project_json_path" ]; then
        echo "Error: project.json not found in $wallpaper_path"
        return 1
    fi

    # Get basic info from project.json
    local type=$(jq -r '.type | ascii_downcase' "$project_json_path")
    local file=$(jq -r '.file' "$project_json_path")
    echo "Detected wallpaper type: $type, main file: $file"

    # --- Logic to determine content source ---
    local content_root=""
    local properties_source_json=""

    # Check if the files are unpacked
    if [ -f "$wallpaper_path/$file" ]; then
        echo "Found unpacked wallpaper."
        content_root="$wallpaper_path"
        properties_source_json="$project_json_path" # Use the external project.json
    else
        # If not, look for a .pkg file to unpack
        echo "Wallpaper is packed. Searching for .pkg file..."
        local pkg_file=""
        if [ -f "$wallpaper_path/project.pkg" ]; then
            pkg_file="$wallpaper_path/project.pkg"
        elif [ -f "$wallpaper_path/preview.pkg" ]; then
            pkg_file="$wallpaper_path/preview.pkg"
        else
            echo "Error: .pkg file not found and main file '$file' is missing."
            return 1
        fi
        
        echo "Found PKG file: $pkg_file"
        content_root="$TMP_DIR/$wallpaper_id"
        properties_source_json="$content_root/project.json" # Use the internal project.json
        
        python "$(dirname "$0")/unpacker.py" "$pkg_file" "$content_root"
        if [ ! -f "$properties_source_json" ]; then
            echo "Error: Could not unpack or find the internal project.json"
            return 1
        fi
    fi
    # --- End of content source logic ---

    # --- Start the player based on type ---
    if [ "$type" == "video" ]; then
        local video_path="$content_root/$file"
        if [ -f "$video_path" ]; then
            echo "Launching mpvpaper for $video_path"
            nice mpvpaper -o "$mpvpaper_options" "$MONITOR" "$video_path" &
            LAST_PID=$!
            write_pid $LAST_PID
        else
            echo "Error: Video file not found at $video_path"
        fi

    elif [ "$type" == "web" ]; then
        local html_path="$content_root/$file"
        if [ -f "$html_path" ]; then
            echo "Launching web_viewer for $html_path"
            # Launch the player in the background. Hyprland rules will handle the rest.
            LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python "$(dirname "$0")/web_viewer.py" "$html_path" &
            LAST_PID=$!
            write_pid $LAST_PID
        else
            echo "Error: HTML file not found at $html_path"
        fi

    elif [ "$type" == "scene" ]; then
        echo "Error: 'scene' type wallpapers are not supported yet."
        return 1
    else
        echo "Unsupported wallpaper type: $type"
        return 1
    fi
}

# --- Main Logic ---

# Argument Handling
echo $1
echo $2
if [ -n "$2" ]; then
	MONITOR=$2
else
# Your monitor name (find with `hyprctl monitors`)
	MONITOR="eDP-2"
fi
# Temporary file to store the PID
	PID_FILE="/tmp/hyprpaper-we-$MONITOR.pid"
# Lock file to prevent race conditions
	LOCK_FILE="/tmp/hyprpaper-we-$MONITOR.lock"
case "$1" in
    stopall)
	stopall
	exit 0
	;;
    stop)
        stop_wallpaper
        exit 0
        ;;
    ""|--help|-h)
        echo "Usage: ./hyprpaper-we.sh <WALLPAPER_ID> ?monitor" 
        echo "run the wallpaper with given id"
        echo "?monitor is optional and can be used to specify the monitor to run the wallpaper on"
        echo "Example: ./hyprpaper-we.sh 123456789"
	    echo "Example: ./hyprpaper-we.sh 123456789 <monitor>"
        echo "used to stop the wallpaper on the default or specified monitor:"
        echo "         ./hyprpaper-we.sh stop"
        echo "         ./hyprpaper-we.sh stop <monitor>"
        echo "used to stop all wallpapers:"
        echo "         ./hyprpaper-we.sh stopall"
        exit 0
        ;;
    *)
        # Check if jq and python are installed
        if ! command -v jq &> /dev/null || ! command -v python &> /dev/null; then
            echo "Error: jq and/or python are not installed. Please install them."
            exit 1
        fi
        set_wallpaper "$1"
        ;;
esac
