#!/bin/sh

killpa(){
	echo "killing pa"
	/usr/bin/pkill pasystray
	/usr/bin/pulseaudio -k
	echo "killed pa"
}
startpa(){
	echo "start pa"
	/usr/bin/pulseaudio --start
	exec /usr/bin/pasystray &
	echo "started pa"
}
killpa
i3lock -n --color "354350"
startpa
