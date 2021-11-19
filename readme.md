# AMPRO Little Board Z80 utilities

Recently I got my hands on a working 3.5" SCSI drive. That
allowed me to complete my ressurected Ampro LB/Z80+ system. I'd
had an ST251N back in the day, but even back then it was
developing bad sectors. Today... today I was happy to get
*anything* off it before powering it down for the last time and
putting it out to pasture for good. It has earned its final rest.

Here, you'll find some of the updated software that I've either
recovered from the ST251N, or from the floppy backup (which
wasn't quite as up to date as what was on the old hard drive), or
created fresh as new needs arose.

I can't imagine that most of this will be of anything more than
minor historical interest to anyone but even so, here it is.

Please note that some of the utilities depend on the reordered
arrangement of the BIOS' I/O setup table in my custom BIOS. They
will not work with a standard Ampro BIOS.

## BIOS

Starting with the last official AMPRO BIOS (3.8), I've added the
following:

* Interrupt driven serial I/O
* Interrupt driven keyboard input
* Interrupt driven ZRDOS compatible clock
* Extended BIOS calls for reader input status, punch output
status, and sending a BREAK to the serial port.

## CONFIG

With the addition of interrupt driven I/O to the BIOS, it became
obvious that the DART/SIO wasn't been set up to quite properly to
work with interrupts. After some light reading of the [Zilog
Z80-SIO Technical
Manual](https://archive.org/details/Zilog_Z80-SIO_Technical_Manual/page/n9/mode/2up)
the solution became apparent; rearrange the order that the
registers were being initialised in, and adding a couple of
channel resets to the mix. Doing this (and keeping all the other
offsets in the BIOS data block the same) meant updating both the
CONFIG and SET utilities to match. To say nothing of my ZMP and
MEX overlays...

## HGEN and SCSIBOOT

New versions of HGEN and SCSIBOOT. HGEN has been extended to
install SCSI controller initialization in the hard drive boot
sector.  This allows automatic booting from non generic SCSI
controllers, such as the Xebec 1410(A) and the DTC 510(A/B), as
well as generic SCSI controllers.

A bug in the SCSI routines in the V1.2 boot EPROM that prevented
the SETPRAM routine from functioning has been corrected in the
V1.3 EPROM.  V1.4 re-uses the EPROM select bit in the control
register to reset the floppy driver controller when the boot
process switches from floppy to hard drive. (This requires a cut
and jumper on the PCB, but the software change is harmless w/o
the hardware change.)

## MOUNT

A utility to allow use of a large hard drive without giving up
too much of your precious TPA via 'mountable volumes''. In my
system, I have two hard drives; A: and B:. 4 different volumes
can be mounted (1 at a time) for B:.

## REMOTE

A utility to move the console from port A to B (and back again),
as well as setting up my 
[Retro WiFi Modem](https://github.com/mecparts/RetroWiFiModem) to
allow dialling in from a remote system.

## SET

With the changes to the SIO initialization in the BIOS data
block, SET had to updated to reflect the new register order as
well. Also corrected a bug in the original software that wasn't
setting things up properly for 450 baud.

## SETDATE

Sets the BIOS clock from the
[Retro WiFi Modem](https://github.com/mecparts/RetroWiFiModem). Time
zone is settable from the command line (whole hours only), and mostly
DST aware (US/Canada rules).

## ZTIME

I use ZTIME a *lot* on another Z80 box running ZSDOS. I really
like the stopwatch function, and thought it would be handy to be
able to use it on the AMPRO (which is still running ZRDOS) as
well. So I made ZTIME ZRDOS and ZSDOS aware.
