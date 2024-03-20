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

use Scalar::Util qw(looks_like_number);

# Constructor of core monitoring object
my $np = Monitoring::Plugin->new(
	usage => "Usage: %s -H <host> -o <first OID> -O <second OID> [-C <community>] [-P <snmp_version>] [-t <timeout>] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ]",
	version => '0.1',
	blurb => 'This plugin checks two snmp values and calcs their ratio',
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
	spec => 'dividend|o=s',
	help => 'First OID to use its value as dividend',
	required => 1
	);
$np->add_arg(
	spec => 'divisor|O=s',
	help => "Second OID to use its value to divide by (divisor)",
	required => 1
	);
$np->add_arg(
	spec => 'base|b=i',
	help => 'Base of ratio. Default is 100 (Percentage). Use 1 to get a float value and 1000 to get per mil',
	default => 100
	);
$np->add_arg(
	spec => 'precision|x=f',
	help => "Precision to round. Default is 0.1",
	default => 0.1
	);
$np->add_arg(
	spec => 'label|l=s',
	help => "Label for performance data",
	default => "Ratio"
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
my $oid1 = $np->opts->dividend;
my $oid2 = $np->opts->divisor;
my $base = $np->opts->base;
my $prec = $np->opts->precision;
my $label = $np->opts->label;

alarm($np->opts->timeout);

# ------------------------------------------------------
# Start here with Main Program
# ------------------------------------------------------

my ($session, $error) = Net::SNMP->session(Hostname => $host, Community => $np->opts->community, Port => $np->opts->port_number, Version => $np->opts->snmp_version);

if(!defined $session) {
	$np->plugin_die("ERROR initializing SNMP session: $error !");
}

my $result;
my $v1;
my $v2;
my $ratio;
my $uom = '';
my $oid;
my $code;

$oid = $np->opts->dividend;
$oid =~ s/^\s+|\s+$//g;
printf "GETTING OID:\t\t$oid\n" if ($np->opts->verbose);

$result = $session->get_request($oid);

if(!defined $result) {
	$error = $session->error();
	$np->plugin_die("ERROR getting first OID: $error !");
}

printf "FIRST RESULT:\t\t$result\n" if ($np->opts->verbose);

if(ref($result) eq 'HASH' and defined $result->{$oid}) {
	$v1 = $result->{$oid};	
	printf "FIRST VALUE:\t\t$v1\n" if ($np->opts->verbose);
}

$oid = $np->opts->divisor;
$oid =~ s/^\s+|\s+$//g;
printf "GETTING OID:\t\t$oid\n" if ($np->opts->verbose);

$result = $session->get_request($oid);

if(!defined $result) {
	$error = $session->error();
	$np->plugin_die("ERROR getting second OID: $error !");
}

printf "SECOND RESULT:\t\t$result\n" if ($np->opts->verbose);

if(ref($result) eq 'HASH' and defined $result->{$oid}) {
	$v2 = $result->{$oid2};
	printf "SECOND VALUE:\t\t$v2\n" if ($np->opts->verbose);	
}

$code = UNKNOWN;

if(looks_like_number($v1)) {
	if(looks_like_number($v2)) {
		if($v2 != 0) {
			printf "Calculate ratio status as percentage.\n\n" if ($np->opts->verbose);
			$ratio = nearest($prec, ($base*$v1/$v2));
			$code = $np->check_threshold($ratio);
		} else {
			#printf "Second value is ZERO. Cannot calculate ratio with a zero as divisor.\n\n" if ($np->opts->verbose);
			$np->plugin_die("Second value is ZERO. Cannot calculate ratio with a zero as divisor!");
		}
	} else {
		#printf "Second value does not seem to be numeric. Cannot calculate ratio!.\n\n" if ($np->opts->verbose);
		$np->plugin_die("Second value does not seem to be numeric. Cannot calculate ratio!");
	}
} else {
	#printf "First value does not seem to be numeric. Cannot calculate ratio!.\n\n" if ($np->opts->verbose);
	$np->plugin_die("First value does not seem to be numeric. Cannot calculate ratio!.\n\n");
	
}

if($base == 100) {
	$uom = "%";
} elsif($base == 1000) {
	$uom = "‰";
}

# Writing Performance-Data
$np->add_perfdata(
	label => $label,
	value => $ratio,
	uom => $uom,
);

$np->plugin_exit(
        return_code => $code,
        message     => " ".$label." = ".$ratio.$uom
  );

# Create Nagios-Output and End the Plugin

#my ($code, $message) = $np->check_messages(join => "<BR>",join_all => "<BR>");
#$np->plugin_exit($code, $message);

exit $ERRORS{'OK'}
# ------------------------------------------------------
# End Main Program
# ------------------------------------------------------