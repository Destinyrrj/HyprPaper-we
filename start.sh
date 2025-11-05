#!/bin/bash
if [ -z "$1" ]; then
	echo "Usage: start.sh <wallpaper_id>"
	echo "start a wallpaper on all monitors"
	exit 1
fi
wallid="$1"
/home/buddy/manbuild/HyprPaper-we/hyprpaper-we.sh stopall
monitors="$(hyprctl monitors | grep ID | cut -c 9- | rev | cut -c 9- | rev)"
for monitor in $monitors; do
	/home/buddy/manbuild/HyprPaper-we/hyprpaper-we.sh "$wallid" $monitor &
done
sleep 3
eww reload
exit 0
