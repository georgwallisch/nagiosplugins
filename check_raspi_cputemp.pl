#!/usr/bin/perl -w

#
# $Id: check_raspi_cputemp.pl / Version 0.1 / 2023-05-02 / gw@phpco.de
#
# Copyright (C) 2023 Georg Wallisch
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
# 0.1 - xx.xx.2023 - First testing version
#

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

use POSIX;
use warnings;
use strict;

use Monitoring::Plugin qw(%ERRORS);

# define some things

my $chunk = 32;  # block size to read
my $cputemppath = "/sys/class/thermal/thermal_zone0/temp";
my $scale = 1000;
my $type = "CPU Temperature";
my $uom = "°C";

# Constructor of core monitoring object
my $np = Monitoring::Plugin->new(
	usage => "Usage: %s [-t <timeout>] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ]",
	version => '0.1',
	blurb => 'This plugin checks a rasperry pi for its CPU temperature status',
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

my $result;
my $rawvalue;
my $value;
my $code;

open my ($fh), '<', $cputemppath or die;
sysread $fh, $rawvalue, $chunk;
$value = $rawvalue / $scale;

if ($np->opts->verbose) {
	printf "Raw temperatur is '$rawvalue':\n";
	printf "CPU Temperature is $value °C\n";
}

$code = $np->check_threshold($value);

# Writing Performance-Data
$np->add_perfdata(
	label => $type,
	value => $value,
	uom => $uom,
);

$np->plugin_exit(
        return_code => $code,
        message     => " ".$type." = ".$value.$uom
  );

exit $ERRORS{'OK'}
# ------------------------------------------------------
# End Main Program
# ------------------------------------------------------

