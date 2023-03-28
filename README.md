# focus

## What is this for ?
The purpose of this tool is to help me being productive by cutting all sources of distraction that get me out of ["the zone"](https://en.wikipedia.org/wiki/Flow_(psychology)) :
* corporate messaging / chat
* my smarphone (which must be connected via USB to the computer)
* emails

It does this by "silencing" all these for a specified duration (aka "focus time"), and "un-silence" them back afterwards.


## How does it work ?
* for processes / applications ("Microsoft Teams", "Evolution", ...) :
  * basically, it "pauses" applications by sending the [SIGSTOP](https://doc.callmematthi.eu/BashIndex_K.html#kill_SIGSTOP) signal to the corresponding PIDs
  * then sleeps for the specified duration ("focus time")
  * then sends the [SIGCONT](https://doc.callmematthi.eu/BashIndex_K.html#kill_SIGCONT) signal to the same list of PIDs
* for a smartphone :
  * the script toggles the 'airplane' mode via ADB
* for my corporate webmail :
  * my "email client" is a Firefox tab
  * the challenge is to find its PID from a script
  * then handle it like other PIDs


## Extras
The script also :
* notifies of the start + end of the "focus time" with a desktop notification + sound
* silences the desktop notifications (XFCE) during the "focus time"
* can be interrupted before the end of the "focus time" with `CTRL-c`


## Limitations
This has been developped + tested in the following environment :
* Ubuntu 22.04.2 LTS
* GNU bash, version 5.1.16(1)-release (x86_64-pc-linux-gnu)
* XFCE 4.16
* an Android smartphone
* can "pause" the webmail tab within Firefox only (may work with others, but not tested)
* ... any probably more


## Requirements
* [adb](https://packages.debian.org/stable/adb)
* [automate-save-page-as](https://github.com/Httqm/automate-save-page-as)
* ... (?)




Feel free to contact me for further details.
