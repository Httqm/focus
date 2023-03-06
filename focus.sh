#!/usr/bin/env bash

. config.sh

focusDurationMinutes=25
listOfApplicationsToSilence='teams'
listOfPidsToSilence=''	# will be populated later

soundStart=/usr/share/sounds/sound-icons/trumpet-12.wav
soundStop=/usr/share/sounds/sound-icons/finish
soundStopEmergency=/usr/share/sounds/sound-icons/prompt
soundPhoneUnauthorized=/usr/share/sounds/sound-icons/cembalo-2.wav


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
	# configure this with 'xfce4-notifyd-config'
	}


silencePids() {
	local applicationTargetMode=$1
	case $applicationTargetMode in
		rest)
			signal=stop
			;;
		wakeUp)
			signal=cont
			;;
	esac
	for pidToSilence in $listOfPidsToSilence; do
		kill -s $signal $pidToSilence
	done
	}


toggleAirplaneMode() {
	local airplaneMode=$1
	[ $(getPhoneStatus) == 'ready' ] && {
		adb shell input keyevent KEYCODE_WAKEUP	# turn screen on ...
		adb shell cmd statusbar expand-settings	# ... so that you can see icons switching
		adb shell cmd connectivity airplane-mode "$airplaneMode"
		}
	}


enterFocusMode() {
	silencePids rest
	toggleAirplaneMode enable
	displayNotification enterDnDMode	# must be done out of 'Do Not Disturb' mode ;-)
	playSound "$soundStart"
	turnXfceDoNotDisturbMode on
	}


leaveFocusMode() {
	toggleAirplaneMode disable
	turnXfceDoNotDisturbMode off
	silencePids wakeUp
	displayNotification leaveDnDMode	# must be done out of 'Do Not Disturb' mode ;-)
	playSound "$soundStop"
	}


checKFilesExist() {
	for requiredFile in "$soundStart" "$soundStop" "$soundStopEmergency" "$soundPhoneUnauthorized"; do
		[ -e "$requiredFile" ] || echo "Missing sound file '$requiredFile'"
	done

	for iconName in "$notificationIconAvailable" "$notificationIconBusy"; do
		nbResults=$(find /usr/share/icons/ -type f -iname "*$iconName*" | wc -l)
		[ "$nbResults" -lt 1 ] && echo "Found no icon named '$iconName'." || :
	done
	}


getPhoneStatus() {
	# When running "adb devices", I can get :
	# - phone is not connected :
	# 	List of devices attached
	# 	(empty line)
	# - phone is plugged but has not yet allowed this PC to debug it
	# 	List of devices attached
	# 	<device_ID>			unauthorized
	# 	(empty line)
	# - phone is connected and ready for ADB commands
	# 	List of devices attached
	# 	<device_ID>			device
	# 	(empty line)
	adb devices | awk ' \
		BEGIN			{ phoneStatus="absent";			} \
		/unauthorized$/	{ phoneStatus="unauthorized";	} \
		/device$/		{ phoneStatus="ready";			} \
		END				{ print phoneStatus;			} \
		'
	}


dontStartWithUnauthorizedPhone() {
	# The phone may have 3 states :
	#	- 'ready'        : this is fine
	#	- 'absent'       : this is fine too
	#	- 'unauthorized' : just missing a few clicks to be handled by this script.
	#		This is an in-between state, and I know how I'll react : stop the script
	#		+ enable USB debugging on the phone + restart the script.
	#		So better blocking from the start anyway ;-)
	[ $(getPhoneStatus) == 'unauthorized' ] && {
		playSound "$soundPhoneUnauthorized"
		echo 'phone is unauthorized'
		exit 1
		}
	}


makeListOfPidsToSilence() {
	# apps listed by name
	for application in $listOfApplicationsToSilence; do
		listOfPidsToSilence="$listOfPidsToSilence $(pidof "$application")"
	done

	# my webmail Firefox tab
	if [ -e "$pidFile" ]; then
		webmailTabPid=$(cat "$pidFile")

		# check we do have a PID value, AND this PID is a Firefox process
		if [ "$webmailTabPid" -ne "$codeNoPidFound" -a $(pgrep -f firefox | grep -c "$webmailTabPid") == 1 ]; then
			listOfPidsToSilence="$listOfPidsToSilence $webmailTabPid"
		else
			echo 'invalid PID, run "getWebmailTabPid.sh"'
			exit 1
		fi
	else
		echo 'PID file not found, run "getWebmailTabPid.sh"'
		exit 1
	fi
	}


main() {
	case "$1" in

		'-c')
			echo "'check' mode :"

			# make sure none of the expected files (sounds, icons, ...) is missing
			fileErrors=$(checKFilesExist)
			echo -n " - files : "
			[ -z "$fileErrors" ] && echo 'OK' || echo -e "\n$fileErrors"

			# report phone status
			echo " - phone status : '$(getPhoneStatus)'"
			;;

		*)	# anything else, normal mode
			dontStartWithUnauthorizedPhone
			makeListOfPidsToSilence
			enterFocusMode
			sleep "$focusDurationMinutes"m
			leaveFocusMode
			;;
	esac
	}

main "$@"
