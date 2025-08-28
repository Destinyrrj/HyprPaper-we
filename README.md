# HyprPaper-WE: Wallpaper Engine For Hyprland

A script-based solution to bring Wallpaper Engine's video and web wallpapers to the Hyprland compositor on Wayland.

This project provides a set of scripts to find, unpack, and display wallpapers from your existing Steam Wallpaper Engine collection. It uses native Wayland tools for rendering, avoiding the need for Wine/Proton to run the wallpapers themselves.

**Disclaimer:** This is a community project and is not affiliated with Wallpaper Engine or its developers. It only supports a subset of wallpapers (video and web) and (for now) does not support interactive scene-based wallpapers.

## Features

-   **Video Wallpaper Support:** Plays video wallpapers in a loop using the efficient `mpvpaper`.
-   **Web Wallpaper Support:** Renders web-based wallpapers (HTML, JS, CSS) using a lightweight GTK4 WebView.
-   **Native Performance:** Uses Wayland-native tools for low resource consumption.
-   **CLI Control:** Easy-to-use command-line interface to set and stop wallpapers.

## How It Works

1.  The main `hyprpaper-we.sh` script takes a Wallpaper Engine ID as input.
2.  It locates the corresponding wallpaper in your Steam library (`~/.steam/steam/steamapps/workshop/content/431960`).
3.  It reads the `project.json` file to determine the wallpaper type (video, web, etc.).
4.  If the wallpaper assets are packed in a `.pkg` file, it uses `unpacker.py` to extract them.
5.  Based on the type, it launches the appropriate player:
    -   **Video:** `mpvpaper` is launched to display the video file on the correct monitor.
    -   **Web:** `web_viewer.py` is launched, which creates a GTK4 window with a WebView. A Hyprland window rule then forces this window to the background layer.
6.  The script saves the process ID (PID) to `/tmp/hyprpaper-we.pid` for easy stopping.

## Prerequisites

-   **Hyprland:** This is designed specifically for the Hyprland Wayland compositor.
-   **Wallpaper Engine:** You must own Wallpaper Engine on Steam and have some wallpapers downloaded.
-   **Python 3**
-   **jq:** A command-line JSON processor.
-   **mpvpaper:** For video wallpapers.
-   **GTK4, gtk4-layer-shell, WebKitGTK & PyGObject:** For web wallpapers.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```

2.  **Install dependencies (for Arch Linux):**
    ```bash
    yay -S jq mpvpaper gtk4 webkitgtk-6.0 python-gobject gtk4-layer-shell
    ```

3.  **Make the main script executable:**
    ```bash
    chmod +x hyprpaper-we.sh
    ```

4.  **Configure Hyprland:**
    Add the following window rules to your `~/.config/hypr/hyprland.conf` file. This is crucial for web wallpapers to appear correctly in the background.

    ```
    # Rules for HyprPaper-WE
    windowrulev2 = workspace special silent, class:^(HyprPaper-WE-Window)$
    windowrulev2 = nofocus, class:^(HyprPaper-WE-Window)$
    windowrulev2 = noanim, class:^(HyprPaper-WE-Window)$
    windowrulev2 = rounding 0, class:^(HyprPaper-WE-Window)$
    ```
    After adding the rules, reload your Hyprland configuration (usually with `SUPER + M` or `SUPER + SHIFT + R`).

## Usage

1.  **Find a Wallpaper ID:**
    Navigate to your Wallpaper Engine workshop directory:
    `ls ~/.steam/steam/steamapps/workshop/content/431960`
    The numbered directories are the IDs.

2.  **Set a wallpaper:**
    ```bash
    ./hyprpaper-we.sh <ID_of_the_wallpaper>
    ```
    Example:
    ```bash
    ./hyprpaper-we.sh 822865320
    ```

3.  **Stop the current wallpaper:**
    ```bash
    ./hyprpaper-we.sh stop
    ```
OR
    **Use the GUI:**
    ```
    python gui.py
    ```
    
## Future Improvements

-   Support for wallpaper properties (colors, speed, etc.).
-   Better multi-monitor support.
