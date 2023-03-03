#!/usr/bin/env bash

codeNoPidFound='0'
resultFile="$(basename "$0" .sh).pid"
[ -f "$resultFile" ] && rm "$resultFile"

tempDir="$(mktemp --tmpdir='/tmp' -d )"
htmlDocumentName='firefoxProcesses.html'


exitIfFirefoxIsNotRunning() {
	[ $(ps -ef | grep -c [f]irefox) -eq 0 ] && {
		debug 'firefox is not running'
		echo "$codeNoPidFound" > "$resultFile"
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
	sed -rn 's|^.*https://office\.com \(([0-9]+)\).*$|\1|p' "$tempDir/$htmlDocumentName" > "$resultFile"
	}


main() {
	exitIfFirefoxIsNotRunning
	getFirefoxAboutProcessesPage
	getPid
	}


main "$@"
