# check_poe_consumption_snmp
[![ShellCheck](https://github.com/antonfischl1980/check_poe_consumption_snmp/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/antonfischl1980/check_poe_consumption_snmp/actions/workflows/shellcheck.yml)

## Intro

This is a Nagios/Icinga compatible check plugin for PoE capable Switches that implement POWER-ETHERNET-MIB.
It queries a switch with SNMP and produces warnings if these values exceed a given threshold (either set in the switch itself or via command arguments).

## Installing

copy `check_poe_consumption_snmp.sh` to your Nagios/Icinga plugin directory (usually `/usr/lib64/nagios/plugins/` )  
Edit your Nagios/Icinga config accordingly.  
For Icinga2 you can copy `check_poe_consumption_snmp.conf` to your CheckCommand-Definitions (usually `/usr/share/icinga2/include/plugins-contrib.d/` )    
If you are running `icinweb2-module-graphite` you can place the provided `check_poe_consumption_snmp.ini` into the template directory (usually `/usr/share/icingaweb2/modules/graphite/templates/` or `/etc/icingaweb2/modules/graphite/templates/` )

## Usage

```
Usage: check_poe_consumption_snmp.sh -H <FQDN or IP> [-C <SNMP-Community>] [-v <snmp_version>] [-w <warning>] [-c <critical>]
 -H <FQDN or IP>        FQDN or IP-Address for SNMP Query (REQUIRED)
 -C <SNMP-Community>    SNMP Community string (OPTIONAL, default: "public")
 -v <snmp_version>      SNMP-Version (OPTIONAL, default: "2c", also currently only 2c is supported)
 -w <warning>           Warning threshold (in %) for watt consumption (OPTIONAL, default: threshold found in SNMP, 50% if no threshold is found)
 -c <critical>          Critical threshold (in %) for watt consumption (OPTIONAL, default: threshold found in SNMP, 80% if no threshold is found)
 -h                     Displays this help message
```
## Credits

[onkelbeh](https://github.com/onkelbeh) for initial idea
