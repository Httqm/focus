#!/usr/bin/env bash

# So far, this script just handles
#	- 1 pomodoro
#	- no break

listOfApplicationsToSilence='teams thunderbird'
durationMinutesPomodoro=25
#durationMinutesBreakShort=5
#durationMinutesBreakLong=20

soundStart=/usr/share/sounds/sound-icons/trumpet-12.wav
soundStop=/usr/share/sounds/sound-icons/finish
soundStopEmergency=/usr/share/sounds/sound-icons/prompt

# see /usr/share/icons/Humanity/status/22
notificationIconAvailable='user-available'	# icon name without path nor extension
notificationIconBusy='user-busy'			# icon name without path nor extension


trap emergencyExit SIGINT	# on CTRL-c


emergencyExit() {
	echo -e '\n\t/!\ Emergency exit\n'
	playSound "$soundStopEmergency"
	leaveFocusMode	# will also play the 'stopSound', no big deal ;-)
	exit 0
	}


playSound() {
	local soundToPlay=$1
	aplay -q "$soundToPlay"
	}


turnXfceDoNotDisturbMode() {
	local mode=$1
	case $mode in
		on)
			doNotDisturbValue=true
			;;
		off)
			doNotDisturbValue=false
			;;
	esac
	xfconf-query -c xfce4-notifyd -p /do-not-disturb -s "$doNotDisturbValue"
	}


displayNotification() {
	local notification=$1
	case $notification in
		enterDnDMode)
			notificationMessage="Entering 'Do Not Disturb' mode"
			shellMessage="${notificationMessage}\nHit 'CTRL-c' for an emergency exit."
			icon="$notificationIconBusy"
			;;
		leaveDnDMode)
			notificationMessage='Leaving "Do Not Disturb" mode'
			shellMessage="${notificationMessage}"
			icon="$notificationIconAvailable"
			;;
	esac
	echo -e "$shellMessage"
	notify-send "$notificationMessage" -i "$icon"
	# notifications can either be sent to :
	#	- the primary monitor
	#	- the monitor having the mouse cursor
	# configure this with xfce4-notifyd-config
	}


silenceApplications() {
	local applicationTargetMode=$1
	case $applicationTargetMode in
		rest)
			signal=stop
			;;
		wakeUp)
			signal=cont
			;;
	esac
	for application in $listOfApplicationsToSilence; do
		for applicationPid in $(pidof "$application"); do
			[ -z "$applicationPid" ] && : || {
				kill -s $signal $applicationPid
#				echo "application '$application' has PID : '$applicationPid'"
				}
		done
	done
	}


toggleAirplaneMode() {
	local airplaneMode=$1
	case $airplaneMode in
		on)
			valueAirplaneMode=1
			valueSvc='disable'
			;;
		off)
			valueAirplaneMode=0
			valueSvc='enable'
			;;
	esac
	adb shell input keyevent KEYCODE_WAKEUP	# turn screen on ...
	adb shell cmd statusbar expand-settings	# ... so that you can check icons ;-)
	adb shell settings put global airplane_mode_on "$valueAirplaneMode"
	adb shell svc data "$valueSvc"
	adb shell svc wifi "$valueSvc"
	}


enterFocusMode() {
	toggleAirplaneMode on
	silenceApplications rest
	displayNotification enterDnDMode	# must be done out of DnD mode ;-)
	playSound "$soundStart"
	turnXfceDoNotDisturbMode on
	}


leaveFocusMode() {
	toggleAirplaneMode off
	turnXfceDoNotDisturbMode off
	silenceApplications wakeUp
	displayNotification leaveDnDMode	# must be done out of DnD mode ;-)
	playSound "$soundStop"
	}


checKFilesExist() {
	for requiredFile in "$soundStart" "$soundStop" "$soundStopEmergency"; do
		[ -e "$requiredFile" ] || echo "Missing sound file '$requiredFile'"
	done

	for iconName in "$notificationIconAvailable" "$notificationIconBusy"; do
		nbResults=$(find /usr/share/icons/ -type f -iname "*$iconName*" | wc -l)
		[ "$nbResults" -lt 1 ] && echo "Found no icon named '$iconName'." || :
	done
	}


main() {
	case "$1" in
		'-c')
			# check mode
			# This mode is used to make sure none of the expected files
			# (sounds, icons, ...) is missing.
			echo "'check' mode (no error below means 'OK')"
			checKFilesExist
			;;
		*)	# anything else, normal mode
#			echo "'normal' mode"
			enterFocusMode
			sleep "$durationMinutesPomodoro"m
#			sleep 10
			leaveFocusMode
			;;
	esac
	}

main "$@"
