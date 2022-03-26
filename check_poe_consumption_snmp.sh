#!/bin/bash

# Default values
SNMP_HOST=""
SNMP_COMMUNITY="public"
SNMP_VERSION="2c"
WARNING=""
CRITICAL=""
SNMP_OID=".1.3.6.1.2.1.105.1.3.1.1" # see http://oidref.com/1.3.6.1.2.1.105.1.3.1.1

usage() {
echo "Usage: $0 -H <FQDN or IP> [-C <SNMP-Community>] [-v <snmp_version>] [-w <warning>] [-c <critical>]" 1>&2
cat <<'EOF' 1>&2
 -H <FQDN or IP>        FQDN or IP-Address for SNMP Query (REQUIRED)
 -C <SNMP-Community>    SNMP Community string (OPTIONAL, default: "public")
 -v <snmp_version>      SNMP-Version (OPTIONAL, default: "2c", also currently only 2c is supported)
 -w <warning>           Warning threshold (in %) for watt consumption (OPTIONAL, default: threshold found in SNMP, 50% if no threshold is found)
 -c <critical>          Critical threshold (in %) for watt consumption (OPTIONAL, default: threshold found in SNMP, 80% if no threshold is found)
 -h                     Displays this help message
EOF
  exit 3;
}

# check for command line arguments
while getopts ":H:C:v:w:c:h:" option; do
  case "${option}" in
    H) SNMP_HOST="$OPTARG";;
    C) SNMP_COMMUNITY="${OPTARG}";;
    v) SNMP_VERSION="${OPTARG}";;
    w) WARNING="${OPTARG}";;
    c) CRITICAL="${OPTARG}";;
    h) usage;;
    *) usage;;
  esac
done

# SNMP_HOST must be set
[ -z "$SNMP_HOST" ] && usage

# Only "v2c" supported for now
[ "$SNMP_VERSION" != "2c" ] && usage

# WARNING and CRITICAL must be decimal numbers or empty
echo "$WARNING"|grep -qE "^[0-9]*+$" || usage
echo "$CRITICAL"|grep -qE "^[0-9]*$" || usage

# Resets position of first non-option argument
shift "$((OPTIND-1))"

SNMP_VALUES="$(snmpbulkwalk -v"$SNMP_VERSION" -c "$SNMP_COMMUNITY" "$SNMP_HOST" "$SNMP_OID" -On -OU 2>&1)"
SNMP_EXIT_CODE=$?

# snmpbulkwalk didn't exit cleanly....
if [ $SNMP_EXIT_CODE -ne 0 ]; then
  echo "UNKNOWN: $SNMP_VALUES"
  exit 3
fi

# no OIDs a
if echo "$SNMP_VALUES" | grep -q "No Such Object"; then
  echo "UNKNOWN: $SNMP_VALUES"
  exit 3
fi


echo "$SNMP_VALUES" | awk -v WARNING="$WARNING" -v CRITICAL="$CRITICAL" '
  BEGIN{exit_value=0;perfdata="|";msg=""}
  # Read SNMP-Table into memory
  $1~/\.[0-9]+\.[0-9]+$/{current_pse_group=gensub(/^.*\.[0-9]+\.([0-9]+)$/, "\\1", "g", $1);pse_groups[current_pse_group]=current_pse_group}
  $1~/\.2\.[0-9]+$/{watts_max[current_pse_group]=$4}
  $1~/\.3\.[0-9]+$/{oper_status[current_pse_group]=$4}
  $1~/\.4\.[0-9]+$/{watts_used[current_pse_group]=$4}
  $1~/\.5\.[0-9]+$/{threshold[current_pse_group]=$4}

  #Lets see what we got (more than one PSE is possible)
  END{
    if(WARNING!=""){warn_percent=WARNING}
    if(CRITICAL!=""){crit_percent=CRITICAL}

    for(pse in pse_groups){
      if(WARNING==""){warn_percent=threshold[pse]}
      if(CRITICAL==""){crit_percent=threshold[pse]}

      if(oper_status[pse]==3){
        printf("CRITIAL: PSE %d is faulty\n",pse);
        exit_value=(exit_value>2)?exit_value:2;
      }else if(oper_status[pse]==2){
        printf("UNKNOWN: PSE %d is off\n",pse)
        exit_value=(exit_value==2)?exit_value:3;
      }

      if(watts_max[pse]>0){
        # Do the math
        warn_watts=watts_max[pse] * warn_percent / 100.0
        crit_watts=watts_max[pse] * crit_percent / 100.0
        watts_used_percent=watts_used[pse] * 100.0 / watts_max[pse]

        if(watts_used[pse]>=crit_watts){
          printf("CRITIAL: PSE %d uses %.2f watts out of a total of %d watts\n", pse, watts_used[pse], watts_max[pse]);
          exit_value=2;
        }else if(watts_used[pse]>=warn_watts){
          printf("WARNING: PSE %d uses %.2f watts out of a total of %d watts\n", pse, watts_used[pse], watts_max[pse]);
          exit_value=(exit_value>1)?exit_value:1;
        }else{
          msg=sprintf("%sOK: PSE %d uses %.2f watts out of a total of %d watts\n", msg, pse, watts_used[pse], watts_max[pse])
        }
        perfdata=sprintf("%s pse_%d_watts=%.2fW;%.2f;%.2f;0;%.2f", perfdata, pse, watts_used[pse], warn_watts, crit_watts, watts_max[pse])
        perfdata=sprintf("%s pse_%d_percent=%.2f%%;%.2f;%.2f;0;100", perfdata, pse, watts_used_percent, warn_percent, crit_percent)
      }else{
        # SNMP is reporting nonsense value for watts_max
        printf("CRITIAL: PSE %d reports %d Watts as maximum - something is not right here\n", pse, watts_max[pse])
        exit_value=2;
      }
    }
    msg=(substr(msg, 1, length(msg)-1))
    printf("%s %s\n",msg,perfdata);
    exit(exit_value)
  }
'
