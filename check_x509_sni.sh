#!/bin/bash
# Icinga 2 | (c) 2012 Icinga GmbH | GPLv2+
# Except of function urlencode which is Copyright (C) by Brian White (brian@aljex.com) used under MIT license

PROG="`basename $0`"

## Function helpers
Usage() {
cat << EOF

Required parameters:
  -l HOSTNAME A hosts name

Optional parameters:
  -w Warning Less remaining time results in state WARNING [25%]
  -c Critical Less remaining time results in state CRITICAL [10%]
  -p PORT The port to check in particular default 443
  -s allow-self-signed Ignore if a certificate or its issuer has been self-signed


EOF
}

Help() {
  Usage;
  exit 0;
}

Error() {
  if [ "$1" ]; then
    echo $1
  fi
  Usage;
  exit 1;
}

## Main
while getopts w:c:shl:p: opt
do
  case "${opt}" in
    w) WGREATER=$OPTARG ;;
    c) CGREATER=$OPTARG ;;
    s) SELFSIGN=1 ;;
    h) Help ;;
    l) HOSTNAME=$OPTARG ;; # required
    p) PORT=$OPTARG ;; # required
   \?) echo "ERROR: Invalid option -$OPTARG" >&2
       Error ;;
    :) echo "Missing option argument for -$OPTARG" >&2
       Error ;;
    *) echo "Unimplemented option: -$OPTARG" >&2
       Error ;;
  esac
done

shift $((OPTIND-1))



for P in HOSTNAME; do
	eval "PAR=\$${P}"

	if [ ! "$PAR" ] ; then
		Error "Required parameter '$P' is missing."
	fi
done

GETENT="getent"
MYSQL="mysql"
SNI="/etc/icingaweb2/modules/x509/sni.ini"
CONFIG="/etc/icingaweb2/modules/x509/config.ini"
DBRESOURCE="/etc/icingaweb2/resources.ini"

if ! [ -f "$SNI" ] ; then
  Error "$SNI not found. Consider installing x509 module."
fi

if ! [ -f "$CONFIG" ] ; then
  Error "$CONFIG not found. Consider installing x509 module or usermod -a -G icingaweb2 nagios"
else
  resource=""
  source <(grep "=" <(grep -A2 'backend' "$CONFIG" | tr -d ' '))
  if [ -z "$resource" ] ; then
    Error "db resource not found. Consider configure x509 module."
  fi
fi

if ! [ -f "$DBRESOURCE" ] ; then
  Error "$DBRESOURCE not found. Consider installing x509 module."
else
  host=""
  dbname=""
  username=""
  password=""
  source <(grep = <(grep -A8 "$resource" "$DBRESOURCE" | tr -d ' '))
  if [ -z "$dbname" ] || [ -z "$username" ] || [ -z "$password" ]; then
    Error "dbname or username or password not found. Consider configure x509 module."
  fi
fi

if [ -z "`which $MYSQL`" ] ; then
  Error "$MYSQL not found in \$PATH. Consider installing it."
fi

if [ -z "`which $GETENT`" ] ; then
  Error "$GETENT not found in \$PATH. Consider installing it."
fi

if [ -z "$PORT" ] ; then
  PORT=443
fi

MASK=128
HOST="$($GETENT ahostsv6 $HOSTNAME | grep STREAM | head -n 1 | cut -d ' ' -f 1)"
if [ -z "$HOST" ] ; then
  MASK=32
	HOST="$($GETENT hosts $HOSTNAME | cut -d ' ' -f1)"
	HOST="$($GETENT ahostsv4 $HOSTNAME | grep STREAM | head -n 1 | cut -d ' ' -f 1)"
fi

if [ -n "$HOST" ] ; then
  CURRENTHOST="$(grep -B1 $HOSTNAME $SNI | head -1 | tr -d '[]')"
  if ! [ -z "$CURRENTHOST" ] ; then
    if [ "$CURRENTHOST" != "$HOST" ] ; then
      sed -e -i $SNI 's/$CURRENTHOST/$HOST/'
    fi
  else
    echo "" >> $SNI
    echo "[$HOST]" >> $SNI
    echo "hostnames = \"$HOSTNAME\"" >> $SNI
  fi
  JOBNAME="$HOSTNAME-$PORT"
  id=$($MYSQL -p"$password" -u "$username" -D "$dbname" -N -B -e "SELECT id FROM x509_job where name = '$JOBNAME';")
  ctime="$(date +%s)""000"
  HOST="$HOST/$MASK"
  if [ -n "$id" ] ; then
    $MYSQL -p"$password" -u "$username" -D "$dbname" -N -B -e "UPDATE x509_job SET cidrs = '$HOST', mtime = '$ctime' WHERE id = '$id';"
  else
    $MYSQL -p"$password" -u "$username" -D "$dbname" -N -B -e "INSERT INTO x509_job (name, author, cidrs, ports, ctime, mtime) VALUE ('$JOBNAME', 'admin', '$HOST', '$PORT', '$ctime', '$ctime');"
  fi
  icingacli x509 scan --job $JOBNAME --full
  params=""
  [ -z "$WGREATER" ] || params="--warning $WGREATER $params"
  [ -z "$CGREATER" ] || params="--critical  $CGREATER $params"
  [ -z "$SELFSIGN" ] || params="--allow-self-signed $params"
  icingacli x509 check host --host $HOSTNAME --port $PORT $params
else
	Error "nslookup fail for $$HOSTNAME"
fi
