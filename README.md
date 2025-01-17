Vestaboard Fires
----------------

This is just a quick and dirty hack to display California wildfire status on
the Vestaboard display I just got.

It has to be running constantly. Every five minutes itt fetches up to four fires
from Cal Fire, gets the details, and then displays their status on the board.
In order to make the board a little more interesting, it displays the last-updated
time in relative format, so that the board changes more often.

It pulls the last updated time from the most-recently updated fire (the API
leaves a lot to be desired).

This code is very gross. I just wanted to get it going quickly.
