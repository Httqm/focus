#!/usr/bin/env bash

focusDurationMinutes=25
listOfApplicationsToSilence='teams'


# sounds
soundStart=/usr/share/sounds/sound-icons/trumpet-12.wav
soundStop=/usr/share/sounds/sound-icons/finish
soundStopEmergency=/usr/share/sounds/sound-icons/prompt
soundPhoneUnauthorized=/usr/share/sounds/sound-icons/cembalo-2.wav


# icons used on the desktop notifications
# see /usr/share/icons/Humanity/status/22
notificationIconAvailable='user-available'	# icon name without path nor extension
notificationIconBusy='user-busy'			# icon name without path nor extension


# no need to tamper these
listOfPidsToSilence=''	# will be populated later
codeNoPidFound='0'
webmailTabPidFile='/tmp/getWebmailTab.pid'	# within '/tmp' so that we won't re-use an old value
											# will be deleted if found to workaround symlink exploits
