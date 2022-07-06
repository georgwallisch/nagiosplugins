#!/bin/bash
filename="$1"
while read -r line || [[ -n "$line" ]]; do
	if [ "$line" != "" ]; then
    		ip="$line"
		/usr/bin/perl -w check_printer_supply_status.pl -H $ip -l --csvdump
	fi
done < "$filename"
