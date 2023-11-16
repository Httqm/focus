#!/usr/bin/env bash

. config.sh

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
# TODO (after switchig to the web version of MS-Teams) :
# - instead of running 1 script that returns 1 PID
# - run 1 script (getWebMailTabPid.sh, rename it accordingly)
# - pass it a list of "needles"
# - let it search
# - then return an array of values :
# - 	app1, pidApp1
# - 	app2, pidApp2
# - 	...
# - and use these here

	if [ -e "$webmailTabPidFile" ]; then
		webmailTabPid=$(cat "$webmailTabPidFile")

		case "$webmailTabPid" in
			'')
				echo "No PID found for webmail browser tab (empty string), won't silence it"
				;;
			"$codeNoPidFound")
				echo "No PID found for webmail browser tab (=$codeNoPidFound), won't silence it"
				;;
			*)
				# check we do have a PID value, AND this PID is a Firefox process
				if [ $(pgrep -f firefox | grep -c "$webmailTabPid") == 1 ]; then
					listOfPidsToSilence="$listOfPidsToSilence $webmailTabPid"
				else
					echo 'invalid PID, run "getWebmailTabPid.sh"'
					exit 1
					# TODO: launch script instead of returning error ?
				fi
				;;
		esac
	else
		echo 'PID file not found, run "getWebmailTabPid.sh"'
		exit 1
		# TODO: launch script instead of returning error ?
	fi
	}


usage() {
	cat <<-EOUSAGE

	$(basename $0) : stay in "the zone" and be more productive by cutting sources of distraction, i.e. notifications :
	  - from your cell phone
	  - from instant messaging apps
	  - "new mail" bell
	  - ...


	USAGE :
	    $0

	    All settings (like "focus" time duration) are in './config.sh'


	options:
	  -c : check mode	Make sure
	                          - none of the expected files (sounds, icons, ...) is missing
	                          - the script can communicate with the phone
	  -h : help		Display this message and exit
	  -s : sound test	Play the notification sounds

	EOUSAGE
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

		'-h')
			usage
			exit 0
			;;

		'-s')
			echo "'sound test' mode :"
			for sound in "$soundStart" "$soundStop" "$soundStopEmergency" "$soundPhoneUnauthorized"; do
				echo " - '$sound'"
				playSound "$sound"
			done
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
