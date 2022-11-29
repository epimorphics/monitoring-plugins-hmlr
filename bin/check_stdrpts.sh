#!/usr/bin/env bash
# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

PROG=$(basename $0)

SCAN=${1:-60}m
GRACE=$((60*${2:-30}))

check () 
{
  REPORTS=$(docker logs --since=$SCAN std-rpts-mgr 2>&1 \
  | jq -r '. | select(has("report-id")) | {ts: .ts, state: .state, name: ."report-id"}' \
  | jq -rs '.? | map( { (.name): . } ) | add | .[] | select(.state!="Completed") | . + {"elapsed":( now - (.ts | sub("\\.[0-9]+Z$"; "Z")| fromdate ) | floor)} | select(.elapsed>'$GRACE') | [.name,.elapsed] | @csv' )

  # first jq filters all the noise - only interested in actual reports.
  #   (also converts report-id to name so I don't have to keep quoting report-id)
  # The second (actually it should be possible to continue the first line but you can't for reasons):
  # -s put everything in one big array.
  # .? don't carp if you got nothing.
  # map( { (.name): . } ) | add | .[] covert into a dictionary keyed on name .
  #   This has the effect of only giving the last entry per report.
  # select(.state!="Completed") | . + {"elapsed":( now - (.ts | sub("\\.[0-9]+Z$"; "Z")| fromdate ) | floor)}'
  #   ignore Comlpeted,
  #   add an elapsed field from ts (need to remove fractions of second become fromdate doesn't understand then),
  #   floor beacuse now gives 10^-6s and this is fatuous here.
  # select(.elapsed>1800) only care about reports that should have had enough time to finish. (edited) 
  case $? in
    0)
      if [ -n "$REPORTS" ]
      then
        for line in $REPORTS
        do
          rep=$(cut -f1 -d, <<< $line)
          age=$(cut -f2 -d, <<< $line)
          printf "Last Update: %2dm\tReport:%s\n" $(($age/60))  $rep
        done
        exit $WARNING
      else
        echo "No stalled reports"
      fi

      exit $OK;;
    1)
      exit $CRITICAL;;
    *) # Unknown service
      exit $UNKNOWN;;
  esac
}


if [ -x /bin/systemctl ] || [ -x /usr/bin/systemctl ]
then

  ACTIVE=$(systemctl is-active docker)

  if [ -z "$ACTIVE" ] || [ "$ACTIVE" == "unknown" ]
  then
    echo "docker: unknown service"
    exit $UNKNOWN
  else
    [ "$ACTIVE" == "active" ] && check
  fi
  exit $CRITICAL

else

  service docker status
  case $? in
    0)
      check;;
    1) # Unknown service
      exit $UNKNOWN;;
    *)
      exit $CRITICAL;;
  esac

fi
