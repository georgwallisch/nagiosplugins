#!/bin/bash
filename="$1"
while read -r line || [[ -n "$line" ]]; do
	if [ "$line" != "" ]; then
    		ip="$line"
		echo "Checking Printer IP - $ip"
		/usr/lib/nagios/plugins/check_snmp -H $ip -P1 -o .1.3.6.1.2.1.43.8.2.1.12.1.1
	fi
done < "$filename"
