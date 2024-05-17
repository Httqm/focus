#!/usr/bin/env bash

. config.sh

tempDir="$(mktemp --tmpdir='/tmp' -d )"
saveAsFilename='firefoxProcesses.html'

urlRegex=''	# will be populated later
			# This is the URL that appears in Firefox's "about:processes" page and
			# that has the PID we're looking for

appName=''			# will be populated later
pidResultFile=''	# will be populated later


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


loadCliParameters() {
	[ -n "$1" ] && appName="$1"			|| { echo 'missing appName';		exit 1; }
	[ -n "$2" ] && pidResultFile="$2"	|| { echo 'missing pidResultFile';	exit 1; }
	# TODO: add 'usage' function
	}


main() {
	exitIfFirefoxIsNotRunning
	loadCliParameters "$@"
	loadAppSettings "$appName"
	getFirefoxAboutProcessesPage
	getFirefoxTabPid
	}


main "$@"
