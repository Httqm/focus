#!/usr/bin/env bash

. config.sh

tempDir="$(mktemp --tmpdir='/tmp' -d )"
saveAsFilename='firefoxProcesses.html'

urlRegex=''	# will be populated later
			# This is the URL that appears in Firefox's "about:processes" page and
			# that has the PID we're looking for

appName=''			# will be populated later
pidResultFile=''	# will be populated later


usage() {
	cat <<-EOUSAGE
	$(basename $0) : Get the PID of a specific Firefox tab (such as the one running your
	                      webmail or a chat application), so that you may "do things" to it
	                      (pause, kill, ...).
	                      Once retreived, the PID number is written into a result file
	                      so that it can be used (and re-used) by external scripts.

	USAGE :
	    $0 -a <appName> -f <pidResultFile>

	options:
	  -a <appName>       : xxx      xxx
	  -f <pidResultFile> : xxx      xxx
	  -h                 : help     Display this help and exit

	EOUSAGE
	}


loadAppSettings() {
	local appName=$1
	case $appName in
		outlook)
			urlRegex='https://office\.com'
			;;
		teams)
			urlRegex='https://microsoft\.com'
			;;
	esac
	}


writePidToFile() {
	local pidValue=$1
	local resultFile=$2
	[ -e "$resultFile" ] && rm "$resultFile"	# to circumvent symlink exploits
	echo "$pidValue" > "$resultFile"
	}


exitIfFirefoxIsNotRunning() {
	[ $(ps -ef | grep -c [f]irefox) -eq 0 ] && {
		debug 'firefox is not running'
		writePidToFile "$codeNoPidFound" "$pidResultFile"
		exit 1
		} || true
	}


debug() {
	local message=$1
	cat <<-EOF
	######################################
	# $message
	######################################
	EOF
	}


getFirefoxAboutProcessesPage() {
	../automate-save-page-as/savePageAs.sh \
		--browser firefox \
		'about:processes' \
		--destination "$tempDir/$saveAsFilename" \
		--load-wait-time 2 \
		--save-wait-time 4 || { echo 'Ooops : child script crashed'; exit 1; }
	# reason why this fails / doesn't belong as expected :
	# because there is a 'save as type' (full page / HTML only / text / all),
	# which preselects the value used the previous time a page was 'Saved as'
	}


getFirefoxTabPid() {
	firefoxTabPid=$(sed -rn 's|^.*'$urlRegex' \(([0-9]+)\).*$|\1|p' "$tempDir/$saveAsFilename")
	writePidToFile "$firefoxTabPid" "$pidResultFile"
	}


echoMessage() {
	local message=$1
	echo -e "\n$message\n"
	}


loadCliParameters() {
	[ "$#" -lt 0 ] && { usage; exit 0; }

	while getopts ':a:f:h' opt; do
		case "$opt" in
			a)	appName="$OPTARG" ;;
			f)	pidResultFile="$OPTARG" ;;
			h)	usage; exit 0 ;;
			\?)	echoMessage "⛔ Invalid option: '-$OPTARG'"; usage; exit 1 ;;
			:)	echoMessage "⚠️  Option '-$OPTARG' requires an argument"; usage; exit 1 ;;
		esac
	done
	}


main() {
	exitIfFirefoxIsNotRunning
	loadCliParameters "$@"
	loadAppSettings "$appName"
	getFirefoxAboutProcessesPage
	getFirefoxTabPid
	}


main "$@"
