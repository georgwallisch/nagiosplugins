#!/usr/bin/perl -w

#
# $Id: check_speedport724_status.pl / Version 0.1 / 2016-05-11 23:39 / gw@phpco.de
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
# 0.1 - 11.05.2016 - Initial Release
# 0.2 - 12.05.2016 - Changed to
#

use POSIX;
use strict;
use warnings;
use FindBin;

#use Nagios::Plugin qw(%ERRORS);
use Monitoring::Plugin qw(%ERRORS);
use Getopt::Long qw(:config no_ignore_case bundling);
use LWP::Simple qw(get);
use JSON; # imports encode_json, decode_json, to_json and from_json.

use vars qw($PROGRAMNAME $SHORTNAME $AUTHOR $COPYR $VERSION);
$PROGRAMNAME = "$FindBin::Script";
$SHORTNAME = "Check Speeport W724V Status";
$AUTHOR = "Georg Wallisch";
$COPYR = "Copyright (C) 2016";
$VERSION = "Version: 0.2";

sub usage();
sub help();
sub getJsonStatus();
sub debugoutput();
sub dumpjson();
sub listvars();

# define Commandline-Options

my $host = "speedport.ip";
my $var = undef;
my $warning = 2000;
my $critical = 1000;
my $list = undef;
my $help = undef;
my $printversion = undef;
my $debug = undef;
my $dump = undef;
my $timeout = 15;
   

#my $np = Nagios::Plugin->new(shortname => "$SHORTNAME");
my $np = Monitoring::Plugin->new(shortname => "$SHORTNAME");  

# get Options

GetOptions(
   "H|host=s"           => \$host,
   "v|variable=s"       => \$var,
   "w|warning=i"        => \$warning,
   "c|critical=i"       => \$critical,
   "l|list"             => \$list,
   "t|timeout=i"        => \$timeout,
   "h|help"             => \$help,
   "V|version"          => \$printversion,
   "debug"        		=> \$debug,
   "dump"        		=> \$dump,
);

#if ($list) {
#	list_available_values();
#}

if ($help) {
	help();
}

if ($printversion) {
	printf "\n";
	printf "$PROGRAMNAME - $VERSION\n\n";
	printf "$COPYR $AUTHOR\n";
	printf "This programm comes with ABSOLUTELY NO WARRANTY\n";
	printf "This programm is licensed under the terms of the GNU General Public License";
	printf "\n\n";
	exit($ERRORS{'UNKNOWN'});
}

if ($dump) {
	dumpjson();
}

if ($debug) {
	debugoutput();
}

if ($list) {
	listvars();
}

if (!defined $var) {
	printf "\nMissing argument [variable]. Please specify what you want to check on your Speedport\n";
	usage();
}

$SIG{'ALRM'} = sub {
	$np->nagios_die("No http response from $host (alarm)");
};

alarm($timeout);

# ------------------------------------------------------
# Start here with Main Program
# ------------------------------------------------------

my $error;
my %flatdata;
my $node;
my $data = getJsonStatus();
my $value;

foreach $node (@{$data}) {
	$flatdata{$node->{'varid'}} = $node->{'varvalue'} unless ($node->{'vartype'} eq 'template');
}

#my %var_keys = keys %flatdata;

if(exists $flatdata{$var}) {

	if($var eq 'dsl_link_status' || $var eq 'dsl_status') {
		if($flatdata{$var} eq 'online') {
			$np->add_message('OK',$var." = ".$flatdata{$var});
		} else {
			$np->add_message('CRITICAL',$var." = ".$flatdata{$var}." (DSL ErrNr: ".$flatdata{dsl_errnr}.")");
		}
	} elsif($var eq 'onlinestatus') {
		if($flatdata{$var} eq 'online') {
			$np->add_message('OK',$var." = ".$flatdata{$var});
		} else {
			$np->add_message('CRITICAL',$var." = ".$flatdata{$var}." (INET ErrNr: ".$flatdata{inet_errnr}.", Fail Reason: ".$flatdata{fail_reason}.")");
		}
	} elsif($var eq 'dsl_downstream' || $var eq 'dsl_upstream') {

		if($flatdata{$var} <= $critical) {
			$np->add_message('CRITICAL',$var." = ".$flatdata{$var}." kbits/s");
		} elsif($flatdata{$var} <= $warning) {
			$np->add_message('WARNING',$var." = ".$flatdata{$var}." kbits/s");
		} elsif($flatdata{$var} > $warning) {
			$np->add_message('OK',$var." = ".$flatdata{$var}." kbits/s");
		} else {
			$np->add_message('UNKNOWN',"Something went wrong ".$var." = ".$flatdata{$var}." kbits/s");
		}
		
		# Writing Performance-Data
		$np->add_perfdata(
			label => $var,
			value => $flatdata{$var},
			uom => "kbits/s",
			min => 0,
			max => 100000,
			);
		
	} elsif($var eq 'hsfon_status') {
		if($flatdata{$var} == 2) {
			$np->add_message('OK',$var." = ".$flatdata{$var});
		} else {
			$np->add_message('CRITICAL',$var." = ".$flatdata{$var});
		}
		
	} elsif($var eq 'lan1_device' || $var eq 'lan2_device' || $var eq 'lan3_device' || $var eq 'lan4_device') {
		
		if($flatdata{$var} <= $critical) {
			$np->add_message('CRITICAL',$var." = ".$flatdata{$var}." ??");
		} elsif($flatdata{$var} <= $warning) {
			$np->add_message('WARNING',$var." = ".$flatdata{$var}." ??");
		} elsif($flatdata{$var} > $warning) {
			$np->add_message('OK',$var." = ".$flatdata{$var}." ??");
		} else {
			$np->add_message('UNKNOWN',"Something went wrong ".$var." = ".$flatdata{$var}." ??");
		}
		
		# Writing Performance-Data
		$np->add_perfdata(
			label => $var,
			value => $flatdata{$var},
			uom => "??",
			min => 0,
			max => 10000000,
			);
		
	} else {
		$np->add_message('OK',$var." = ".$flatdata{$var});
	}	
	

} else {
	printf "\nVariable $var does not exist. \n";
	printf "Please use option -l or --list to show available variables\n";
	usage();
} 

#use Data::Dumper;
#print Dumper $flatdata;


my ($code, $message) = $np->check_messages(join => "<BR>",join_all => "<BR>");
$np->nagios_exit($code,$message);

# ------------------------------------------------------
# End Main Program
# ------------------------------------------------------

sub getJsonStatus () {
	# Only valid for Speedport W724V Typ C
	# TODO: must fetch this variables from Speedport to make it work with all Types (A, B & C)
	my $csrf_token = 'sercomm_csrf_token';
	
	my $JSONSource = "/data/Status.json";
	my $timestamp = localtime(time);
	my $rand = int(rand(1001));
	
	my $status_url = "http://".$host.$JSONSource."?_time=".$timestamp."&_rand=".$rand."&csrf_token=".$csrf_token;
	my $status_json_data = get $status_url;
	
	$np->nagios_die("Unable to get JSON data from $host") unless defined($status_json_data);
	
	my $status_data = decode_json $status_json_data;
	
	$np->nagios_die("Unable to parse JSON data") unless defined($status_data);
	
	return $status_data;
}

sub debugoutput() {
	my $node;
	my $subnode;
	
	my $data = getJsonStatus();
	
	print "---\nDEBUG OUTPUT\n---";
	foreach $node (@{$data}) {
			print "\n$node->{'varid'} ($node->{'vartype'}): "; 
			if(ref($node->{'varvalue'}) eq 'ARRAY') {
				foreach $subnode (@{$node->{'varvalue'}}) {
					print "\n\t$subnode->{'varid'} ($node->{'vartype'}): $subnode->{'varvalue'}";
				}
			} else {
				print "$node->{'varvalue'}";
			}
	}
	print "\n---\n";
	exit($ERRORS{'UNKNOWN'});
}

sub dumpjson() {
	my $data = getJsonStatus();
	use Data::Dumper;
	print Dumper $data;
	exit($ERRORS{'UNKNOWN'});
}

sub listvars() {
	my $node;
	my $data = getJsonStatus();
	
	print "---\nA List of available status variables\n";
	foreach $node (@{$data}) {
			print "\n$node->{'varid'}" unless ($node->{'vartype'} eq 'template');
	}
	print "\n---\n";
	exit($ERRORS{'UNKNOWN'});
}

sub usage () {
	printf "\n";
	printf "USAGE: $PROGRAMNAME [-H <hostname>] -v <variable>\n\n";
	printf "$PROGRAMNAME $VERSION\n";
	printf "$COPYR $AUTHOR\n";
	printf "This programm comes with ABSOLUTELY NO WARRANTY\n";
	printf "This programm is licensed under the terms of the GNU General Public License";
	printf "\n\n";
	exit($ERRORS{'UNKNOWN'});
	}

sub help () {
	printf "\n\n$PROGRAMNAME $VERSION\n";
	printf "Plugin for Nagios and Icinga \n";
	printf "checks the status of a Speedport W724V Router.\n";
	printf "\nUsage:\n";
	printf "   -H (--hostname)		Hostname to query - (default=speedport.ip)\n";
	printf "   -v (--variable)		Specify the status variable you want to check (required)\n";
	printf "   -l (--list)			List all available status variables\n";	
	printf "   -w (--warning)		Warning threshold\n";
	printf "   -c (--critical)		Critical threshold\n";
	printf "   -V (--version)		Plugin version\n";
	printf "   -t (--timeout)		Seconds before the plugin times out (default=$timeout)\n";
	printf "   --debug			Debug output of status data\n";
	printf "   --dump			Dump json status data\n";
	printf "   -h (--help)			Usage help \n\n";
	printf "See http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n";
	printf "for details and examples of the threshold form\n\n";
	exit($ERRORS{'OK'});
}
