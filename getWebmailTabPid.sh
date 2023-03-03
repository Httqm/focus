#!/usr/bin/env bash

. config.sh

tempDir="$(mktemp --tmpdir='/tmp' -d )"
htmlDocumentName='firefoxProcesses.html'


writeToPidFile() {
	# to circumvent symlink exploits
	local value=$1
	[ -e "$pidFile" ] && rm "$pidFile"
	echo "$value" > "$pidFile"
	}


exitIfFirefoxIsNotRunning() {
	[ $(ps -ef | grep -c [f]irefox) -eq 0 ] && {
		debug 'firefox is not running'
		writeToPidFile "$codeNoPidFound"
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
		--destination "$tempDir/$htmlDocumentName" \
		--load-wait-time 2 \
		--save-wait-time 4
	}


getPid() {
	writeToPidFile $(sed -rn 's|^.*https://office\.com \(([0-9]+)\).*$|\1|p' "$tempDir/$htmlDocumentName")
	}


main() {
	exitIfFirefoxIsNotRunning
	getFirefoxAboutProcessesPage
	getPid
	}


main "$@"
