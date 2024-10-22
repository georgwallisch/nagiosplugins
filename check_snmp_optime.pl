#!/usr/bin/perl -w

#
# $Id: check_snmp_ratio.pl / Version 0.1 / 2024-03-20 / gw@phpco.de
#
# Copyright (C) 2024 Georg Wallisch
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
# 0.1 - xx.xx.2024 - First testing version
#

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

use POSIX;
use warnings;
# use strict;

use Monitoring::Plugin qw(%ERRORS);
use Math::Round qw(nearest);
use Net::SNMP;

# Constructor of core monitoring object
my $np = Monitoring::Plugin->new(
	usage => "Usage: %s -H <host> -o <OID> [-C <community>] [-P <snmp_version>] [-t <timeout>] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ]",
	version => '0.1',
	blurb => 'This plugin checks a snmp values which represents a time period as a string and converts it to a comparable integer value',
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
	spec => 'oid|o=s',
	help => 'OID to read its value',
	required => 1
	);
$np->add_arg(
	spec => 'precision|x=f',
	help => "Precision to round. Default is 1 (integer value)",
	default => 1
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

my $host = $np->opts->hostname;
my $oid = $np->opts->oid;
my $prec = $np->opts->precision;
my $label = "time period";

alarm($np->opts->timeout);

# ------------------------------------------------------
# Start here with Main Program
# ------------------------------------------------------

my ($session, $error) = Net::SNMP->session(Hostname => $host, Community => $np->opts->community, Port => $np->opts->port_number, Version => $np->opts->snmp_version);

if(!defined $session) {
	$np->plugin_die("ERROR initializing SNMP session: $error !");
}

my $result;
my $value;
my $uom = 's';
my $code = UNKNOWN;

$oid =~ s/^\s+|\s+$//g;
printf "GETTING OID:\t\t$oid\n" if ($np->opts->verbose);

$result = $session->get_request($oid);

if(!defined $result) {
	$error = $session->error();
	$np->plugin_die("ERROR getting OID: $error !");
}

printf "RESULT:\t\t$result\n" if ($np->opts->verbose);

if(ref($result) eq 'HASH' and defined $result->{$oid}) {
	$value = $result->{$oid};	
	printf "VALUE:\t\t$value\n" if ($np->opts->verbose);
}

my $months = 0;
my $days = 0;
my $hours = 0;
my $minutes = 0;
my $seconds = 0;

if($value =~ m/(\d+)M/) {
	$months = $1;
}

if($value =~ m/(\d+)D/) {
	$days = $1;
}

if($value =~ m/(\d{1,2}):(\d{2}):(\d{2})/) {
	$hours = $1;
	$minutes = $2;
	$seconds = $3;
}
my $fmin = 60;
my $fhour = 60 * $fmin;
my $fday = 24 * $fhour;
my $fmonth = 31 * $fday;

my $period = $months * $fmonth + $fday * $days + $fhour * $hours + $fmin * $minutes + $seconds;

$code = $np->check_threshold($period);

# Writing Performance-Data
$np->add_perfdata(
	label => $label,
	value => $period,
	uom => $uom,
);

$np->plugin_exit(
        return_code => $code,
        message     => $label." = ".$period.$uom." (".$value.")"
  );

# Create Nagios-Output and End the Plugin

#my ($code, $message) = $np->check_messages(join => "<BR>",join_all => "<BR>");
#$np->plugin_exit($code, $message);

exit $ERRORS{'OK'}
# ------------------------------------------------------
# End Main Program
# ------------------------------------------------------