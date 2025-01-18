Vestaboard Fires
----------------

This is just a quick and dirty hack to display California wildfire status on
the Vestaboard display I just got.

The code must run constantly, on some local machine with internet access.
Every five minutes it fetches up to four fires
from Cal Fire, gets the details, and then displays their status on the board.
In order to make the board a little more interesting, it displays the last-updated
time in relative format, so that the board changes more often.

It pulls the last updated time from the most-recently updated fire (the API
leaves a lot to be desired).

This code is very gross. I just wanted to get it going quickly.

## Building

You need a Swift 6+ compiler installed. I’ve only built this on macOS, ymmv.
Clone or download the repo. cd to the directory, type `swift run`. Or open
`Package.swift` with Xcode, and run it from there.
