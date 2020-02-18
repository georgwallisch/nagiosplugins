#!/usr/bin/perl -w

#
# $Id: check_raspi_status.pl / Version 0.1 / 2020-02-17 / gw@phpco.de
#
# Copyright (C) 2020 Georg Wallisch
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
# 0.1 - xx.xx.2020 - First testing version
#

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

use POSIX;
use warnings;
use strict;

use Monitoring::Plugin qw(%ERRORS);
#use Math::Round qw(nearest);
# define some things

# Constructor of core monitoring object
my $np = Monitoring::Plugin->new(
	usage => "Usage: [-t <timeout>] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ]",
	version => '0.1',
	blurb => 'This plugin checks whether debian-goodies\' checkrestarts reports any processes need to be restarted after an upgrade',
	);

# add options
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
alarm($np->opts->timeout);

# ------------------------------------------------------
# Start here with Main Program
# ------------------------------------------------------

#my @valuelist;
#my %data;
my $result;
#my $oid;
#my $item;
#my $i;
#my $used;
#my $capacity;
#my $type = undef;

my $value = $np->opts->value;


$np->plugin_die("No value to check given!") unless (defined $value and $value ne "");

my $requirements = system('dpkg-query', '-W', "-f='${Status} ${Version}\n'", 'debian-goodies');



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

