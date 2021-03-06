#!/usr/bin/perl -w

#
# $Id: check_printer_supply_status.pl / Version 0.5 / 2017-10-12 / gw@phpco.de
#
# Copyright (C) 2016 Georg Wallisch
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# Report bugs to:  gw@phpco.de
#
#
# CHANGELOG:
#
# 0.1 - xx.xx.2016 - First testing version
# 0.2 - 20.06.2016 - rewritten using Monitoring::Plugin
# 0.3 - 10.10.2017 - added support for brother printers
# 0.4 - 11.10.2017 - added rounding of calculated result
# 0.5 - 12.10.2017 - some fixes
#

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

use POSIX;
use warnings;
#use strict;

use Monitoring::Plugin qw(%ERRORS);
use Math::Round qw(nearest);
use Net::SNMP;

# define SNMP OIDs

my $base_oid = ".1.3.6.1.2.1.43.11.1.1";
my $supply_type_oid = ".6.1";
my $supply_capacity_oid = ".8.1";
my $supply_used_oid = ".9.1";
my $printer_type_oid = ".1.3.6.1.2.1.25.3.2.1.3.1";
my $printer_type = undef;

# Constructor of core monitoring object
my $np = Monitoring::Plugin->new(
	usage => "Usage: %s -H <host> [-C <community>] [-P <snmp_version>] [-s <supply>] [-t <timeout>] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ]",
	version => '0.5',
	blurb => 'This plugin checks a printer for its supply status values',
	);

# add options
$np->add_arg(
	spec => 'hostname|H=s',
	help => 'Hostname to query - (required). ',
	required => 1,
	);
$np->add_arg(
	spec => 'community|C=s',
	help => 'SNMP read community (default=public). ',
	default => 'public',
	);
$np->add_arg(
	spec => 'snmp_version|P=s',
	help => 'SNMP Protocol Version v1 (default) or v2c',
	default => 'v1',
	);
$np->add_arg(
	spec => 'port_number|p=i',
	help => 'SNMP Port (default=161)',
	default => 161,
	);
$np->add_arg(
	spec => 'list|l',
	help => 'List all supply values available on specified host. Use to see what supply infos your printer provides.',
	);
$np->add_arg(
	spec => 'supply|s=s',
	help => "Supply name to query. This is REGEX parameter. So just try querying 'black' or 'drum'.",
	);
$np->add_arg(
	spec => 'entry|n=i',
	help => "Entry number as listed to query. Use --list or -l to list all available supply values.",
	);
$np->add_arg(
	spec => 'csvdump|csv',
	help => "Print list as a comma separated list. Only to use with --list or -l.",
	);
$np->add_arg(
	spec => 'csv_separator=s',
	help => "CSV Separator character. default ';'",
	default => ';',
	);
$np->add_arg(
	spec => 'dont_strip_sn',
	help => "Usually a serial number provided in a suply value is stripped. Use this option to keep the S/N.",
	);
$np->add_arg(
	spec => 'warning|w=s',
	help => 'Warning Threshold. See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format. ',
	);
$np->add_arg(
	spec => 'critical|c=s',
	help => 'Warning Threshold. See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format. ',
	);

# Parse and process arguments
$np->getopts;

my $host 	= $np->opts->hostname;
my $supply = $np->opts->supply;
my $entry = $np->opts->entry;
my $separator = $np->opts->csv_separator;

alarm($np->opts->timeout);

# ------------------------------------------------------
# Start here with Main Program
# ------------------------------------------------------

my ($session,$error) = Net::SNMP->session(Hostname => $host, Community => $np->opts->community, Port => $np->opts->port_number, Version => $np->opts->snmp_version);

my @valuelist;
my %data;
my $result;
my $oid;
my $item;
my $i;
my $used;
my $capacity;
my $type = undef;
my $value;
	
for ($i = 1; $i < 11; $i++) { 
	$oid = $base_oid.$supply_type_oid.'.'.$i;
	#$result = undef;
	$result = $session->get_request($oid);
	
	if(ref($result) eq 'HASH' and defined $result->{$oid}) {
		$value = $result->{$oid};
		unless($np->opts->dont_strip_sn) {
			$value =~ s/\s*S\/?N\:?.*//i
		}
		%data = (oid => $oid, i => $i, value => $value);
		push(@valuelist, {%data});
	}
}

if($np->opts->list) {

	#use Data::Dumper;
	#print Dumper(@valuelist);
	
	$result = $session->get_request($printer_type_oid);
	if(ref($result) eq 'HASH' and defined $result->{$printer_type_oid}) {
		$printer_type = $result->{$printer_type_oid};
	}
	$session->close;
	
	if($np->opts->csvdump) {
		
		for $item (@valuelist) {
			print $host.$separator;
			print $printer_type.$separator;
			print $item->{oid}.$separator;
			print $item->{i}.$separator;
			print $item->{value}."\n";
		}
	
		exit $ERRORS{'OK'}


	} else {
	
		printf "\nAvailable supply values on Host $host:\n";

		if(defined $printer_type) {
			printf "\nTYPE: $printer_type\n";
		} else {
			printf "\nERROR: Could not determine type of that printer!\n";
		}
	
		for $item (@valuelist) {
			#if(ref($item) eq 'HASH') {
				print "\n- (",$item->{i} ,") ", $item->{value};
			#}
			if ($np->opts->verbose) {
				print " (OID: ",$item->{oid},")";
			}
		}
		printf "\n\n\n";
		$np->plugin_die("That's it!"); 
	}
}


$i = undef;

if(defined $entry and $entry > 0) {
	for $item (@valuelist) {
		if($item->{i} == $entry) {
			$i = $item->{i};
			$type = $item->{value};
			last;
		}
	}
	$np->plugin_die("There is no supply entry number '".$entry."' for this host") unless (defined $i and $i > 0);

} elsif(defined $supply and $supply ne "") {
	for $item (@valuelist) {
		if($item->{value} =~ /$supply/i) {
			$i = $item->{i};
			$type = $item->{value};
			last;
		}
	}
	$np->plugin_die("There is no supply value like '".$supply."' for this host") unless (defined $i and $i > 0);
	
} else {
	$np->plugin_die("No valid supply value given! Use option -s or -n to define value to query!");
}

$np->plugin_die("Supply value not available for this host") unless (defined $i and $i > 0);

$oid = $base_oid.$supply_used_oid.'.'.$i;
$result = $session->get_request($oid);
if(ref($result) eq 'HASH' and defined $result->{$oid}) {
	$used = $result->{$oid};	
}

$oid = $base_oid.$supply_capacity_oid.'.'.$i;
$result = $session->get_request($oid);
if(ref($result) eq 'HASH' and defined $result->{$oid}) {
	$capacity = $result->{$oid};	
}

if ($np->opts->verbose) {
	printf "Raw values for '$type':\n";
	printf "USED:\t\t$used\n";
	printf "CAPACITY:\t$capacity\n\n";
}

my $status;
my $uom;
my $code;

if($capacity > 0 and $used >= 0 and $used <= $capacity) {
	printf "Calculation status as percentage by used and capacity values.\n\n" if ($np->opts->verbose);
	$status = nearest(.1, (100*$used/$capacity));
	$uom = "%";
	$code = $np->check_threshold($status);
} else {
	printf "The component does not have a measurable status indication.\n\n" if ($np->opts->verbose);
	if($used == -3) {
		# A value of (-3) means that the printer knows that there is some supply/remaining space
		$code = OK;		
	} elsif($used == -2) {
		# The value (-2) means unknown
		$code = WARNING;	
	} elsif($used == 0) {
		# Something is empty!
		$code = CRITICAL;
	} elsif($used > 0) {
		printf "No Capacity value found, thus we only know an absolute pages value.\n\n" if ($np->opts->verbose);
		$code = $np->check_threshold($used);
	} else {
		printf "Used value does not make sense at all.\n\n" if ($np->opts->verbose);
		$code = UNKNOWN;
	}
	$status = $used;
	$uom = '';
}

# Writing Performance-Data
$np->add_perfdata(
	label => $type,
	value => $status,
	uom => $uom,
);

$np->plugin_exit(
        return_code => $code,
        message     => " ".$type." = ".$status.$uom
  );

# Create Nagios-Output and End the Plugin

#my ($code, $message) = $np->check_messages(join => "<BR>",join_all => "<BR>");
#$np->plugin_exit($code, $message);

exit $ERRORS{'OK'}
# ------------------------------------------------------
# End Main Program
# ------------------------------------------------------

