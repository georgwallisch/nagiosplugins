#!/bin/bash
filename="$1"
while read -r line || [[ -n "$line" ]]; do
	if [ "$line" != "" ]; then
    		ip="$line"
		echo "Checking Printer IP - $ip"
		/usr/bin/perl -w check_printer_supply_status.pl -H $ip $2 $3 $4 $5 $6
	fi
done < "$filename"
