#!/usr/bin/perl -w

#
# $Id: check_rrd.pl / Version 1.1 / 2018-04-26 / gw@phpco.de
#
# Copyright (C) 2018 Georg Wallisch
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
# 1.0 - 2008-09-07 inital version for NETWAYS Nagios Konferenz at Nuernberg by wob (at) swobspace (dot) net
# 1.1 - 26.04.2018 - rewritten using Monitoring::Plugin
#
# -----------------------------------------------

#use strict;
use warnings;
use POSIX qw(strftime);

use Monitoring::Plugin qw(%ERRORS %STATUS_TEXT);
use Math::Round qw(nearest);
use RRDs;

# -- Constructor of core monitoring object
my $np = Monitoring::Plugin->new(
	usage => "Usage: \
 %s -R rrd_file --ds data_source [--cf CF] [-v] \
	[--start timespec] [--end timespec] [--resolution seconds] \
	[--compute MAX|MIN|AVERAGE|PERCENT] \
	[--na-value-returncode OK|WARNING|ERROR|UNKNOWN] \
	[--text-label label] [--performance-label label]
	[--clip-warn-level percent] [--clip-crit-level percent] \
	[-w warning_threshold] [-c critical_threshold]
 %s -R rrd_file --info
 %s -R rrd_file --age [-w warning_threshold] [-c critical_threshold]
 %s [-h|-V]",
	version => '1.1',
	blurb => 'Nagios plugin for checking data and and age of rrd files',
	);

# -- add options
$np->add_arg(
	spec => 'rrdfile|R=s',
	help => 'Path to RRD file - (required). ',
	required => 1,
	);
$np->add_arg(
	spec => 'ds=s',
	help => 'Select data source (DS) from rrd file.',
	);
$np->add_arg(
	spec => 'cf=s',
	help => 'RRD consolidation function, must exist for the specified data source and time interval in the rrd file. If unsure, use check_rrd.pl --info to get the available CFs. Examples: MIN, MAX, AVERAGE.',
	default => 'AVERAGE',
	);
$np->add_arg(
	spec => 'start=s',
	help => 'Specify the start time of observation, i.e. \'-1h\'. See man rrdfetch for more information. Default is \'-1h\'.',
	default => '-1h',
	);
$np->add_arg(
	spec => 'end=s',
	help => 'Specify the end of the time interval, i.e. \'now\'. See man rrdfetch for more information. Default is \'now\'.',
	default => 'now',
	);
$np->add_arg(
	spec => 'resolution|i',
	help => 'Specify a time resolution, this means try to select the round robin archives with the matching time resolution. The resolution has to be specified in seconds, not primary data points. This options goes transparently to rrdfetch. For more information see man rrdfetch and take care of the hint in the manpage especially on the dependency between resolution and time interval.',
	default => 1,
	);
$np->add_arg(
	spec => 'na_values_returncode|na-value-returncode=s',
	help => 'Some times there is no valid value in the fetched data from rrd file. --na-value-returncode specifies how to proceed this value. If one value is not available, --compute=MIN|MAX|AVERAGE exits with the specified value (default: CRITICAL). If --compute=PERCENT, this single value is treated as one single OK|WARNING|CRITICAL, the result depends on the percents of good or bad values. UNKNOWN make no sense with --compute=PERCENT.',
	default => 'CRITICAL',
	);
$np->add_arg(
	spec => 'compute=s',
	help => 'rrdfetch returns an array of values. MAX selects only the greatest value, \
	MIN the smallest value and AVERAGE averages all values of the returned \
	array. The result is compared with the specified threshold to get the \
	return value for Nagios (OK, WARNING, CRITICAL). \
	\
	PERCENT is a little different. Now all values of the returned array are \
	compared with the thresholds, then the plugins checks how much values give \
	an OK (and not an ERROR) state. Example: --clip-warn=70:100 --clip-crit=50:100 \
	means: if more than 70 percent of the fetched values ar ok, the plugin \
	returns OK. If the matching good values are between 70 and 50 percent, the \
	plugin returns a WARNING, an CRITICAL, if less then 50 percent of the\ 
	observed values are OK.',
	default => 'AVERAGE',
	);
$np->add_arg(
	spec => 'clip_warn_level|clip-warn-level=i',
	help => 'Clip-Level for use with --compute=PERCENT. The Level has to specified in threshold format. Example 70 or 0:70 means, check_rrd.pl returns OK, if more than 70% of the returned values are ok, and WARNING, if less than 70% are OK related to the specified boundaries in --warning and --critical.',
	default => 100,
	);
$np->add_arg(
	spec => 'clip_crit_level|clip-crit-level=i',
	help => 'See --clip-warn-level',
	default => 100,
	);
$np->add_arg(
	spec => 'info',
	help => 'Prints out the header information of the rrd file and exits. Use this option for a quick look inside the rrd file if you are unsure about data source names an available consolidation functions.',
	);
$np->add_arg(
	spec => 'age',
	help => 'checks, if the last update is within the threshold specified with --warning and --critical. The units of the threshold values are seconds. Example: --age --warning 0:300 means OK, if last update was in the last 300 seconds, and WARNING if the last update was more than 300 seconds ago.',
	);
$np->add_arg(
	spec => 'warning|w=s',
	help => 'Warning Threshold. See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format. ',
	);
$np->add_arg(
	spec => 'critical|c=s',
	help => 'Warning Threshold. See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format. ',
	);
$np->add_arg(
	spec => 'debug',
	help => 'Enable Debug mode.',
	default => 0,
	);
$np->add_arg(
	spec => 'round|prec|precision=f',
	help => 'Rounds the values to the nearest multiple of the target value. e.g. 0.1',
	);

# -- Parse and process arguments
$np->getopts;

# -----------------------------------------------
# vars vars
# -----------------------------------------------

my $rrdfile = $np->opts->rrdfile;
my $mode = 'cf'; # cf|age|info
my $mode_count = 0;		# count of specified possible mode, only 0 or 1 is allowed;
my $debug = $np->opts->debug;
my $ds_index = -1;
my $na_values_returncode;
my $text_label = undef;
my $performance_label = undef;
my $result = UNKNOWN;
my $compute = $np->opts->compute;
my $fetch_start;
my $fetch_step;
my $fetch_dsnames;
my $fetch_data;
my $notavailable = 0;

# -- Alarm

#$SIG{ALRM} = sub { $np->nagios_die("Timeout reached"); }; 
alarm($np->opts->timeout);

# -- mode
if ($np->opts->age) {
   $mode_count++ ;
   $mode = 'age';
}
if ($np->opts->info) {
   $mode_count++ ;
   $mode = 'info';
}

if ($mode_count > 1) {
	$np->nagios_die("Please use only one of these option --cf, --info, --age, not more than one!");
}

$na_values_returncode = $ERRORS{$np->opts->na_values_returncode};

if ( ! defined($na_values_returncode)) {
	    $np->nagios_die("--na-values-returncode: please use one of OK, WARNING, CRITICAL, UNKNOWN");
}

if ( ! grep /^$compute$/, ('MIN', 'MAX', 'AVERAGE', 'PERCENT')) {
	    $np->nagios_die("--compute: please use one of MIN, MAX, AVERAGE, PERCENT. You had ".$np->opts->compute);
}
# -- thresholds: no global set_threshold, specify it explizitly in check_threshold
if ($debug) {
	if (defined($np->opts->warning)) {
		print "DEBUG: warn= ".$np->opts->warning."\n" ;
	} else {
		print "DEBUG: warning threshold not set\n" ;
	}
	
	if (defined($np->opts->critical)) {
		print "DEBUG: crit= ".$np->opts->critical."\n";	
	} else {
		print "DEBUG: critical threshold not set\n" ;
	}
	if (defined($np->opts->round)) {
		print "DEBUG: Rounding values to ".$np->opts->round."\n";	
	} else {
		print "DEBUG: No rounding. Showing full precision.\n" ;
	}
}

# -----------------------------------------------------------------------
# main
# -----------------------------------------------------------------------

#In case the file is a glob expression (*), expand it and check if matches
if ( ! -r $rrdfile ) {
    my @filelist = glob "$rrdfile";
    if ( ! @filelist) {
	    $np->nagios_die("rrdfile $rrdfile not readable or does not exist");
    } elsif ( scalar(@filelist)!=1 ) {
            $np->nagios_die("Glob matches more than one file @filelist\n");
    } else {
	   $rrdfile=$filelist[0];
    }
}

# ----------------------------------------
#  mode = info
# ----------------------------------------

if ( "$mode" eq "info" ) {
   my $hash = RRDs::info("$rrdfile");
   # -- error handling
   my $ERR=RRDs::error;
   $np->nagios_die( "could not info header from $rrdfile: $ERR") if $ERR;

   my %RRA;
   my %DS;
   foreach my $key (sort keys %$hash){
      # ds[2].type = GAUGE
      if ( $key =~ m/ds\[(.+)\].type/ ) {
         $DS{$1}{'TYPE'} = $$hash{$key};
      }
      # rra[8].cf = MIN
      # rra[8].pdp_per_row = 1
      # rra[8].rows = 2880
      # rra[8].xff = 0.5
      if ( $key =~ m/rra\[(\d+)\].cf/ ) {
         $RRA{$1}{'CF'} = $$hash{$key};
      }
      if ( $key =~ m/rra\[(\d+)\].pdp_per_row/ ) {
         $RRA{$1}{'PDP'} = $$hash{$key};
      }
      if ( $key =~ m/rra\[(\d+)\].rows/ ) {
         $RRA{$1}{'ROWS'} = $$hash{$key};
      }
      if ( $key =~ m/rra\[(.+)\].xff/ ) {
         $RRA{$1}{'XFF'} = $$hash{$key};
      }
   }
   foreach my $key ( sort keys %DS ) {
      my $msg = sprintf "DS: NAME=%-10s", $key;
      $msg .= sprintf " TYPE=%-7s", $DS{$key}->{'TYPE'};
      print STDERR "$msg\n";
   }
   print STDERR "--\n";
   foreach my $key ( sort {$a <=> $b} keys %RRA ) {
      my $msg = sprintf "RRA[%3d]:", $key;
      $msg .= sprintf " CF=%-7s", $RRA{$key}->{'CF'};
      $msg .= sprintf " PDP=%-4s", $RRA{$key}->{'PDP'};
      $msg .= sprintf " ROWS=%-5s", $RRA{$key}->{'ROWS'};
      $msg .= sprintf " XFF=%-4s", $RRA{$key}->{'XFF'};
      print STDERR "$msg\n";
   }

   # -- exit and info
   $np->nagios_die("mode $mode is only for debugging purposes, not for use with nagios");
}

# ----------------------------------------
# mode = age
# ----------------------------------------

if ( "$mode" eq "age" ) {

   my $lastupdate = RRDs::last("$rrdfile");
   # -- error handling
   my $ERR=RRDs::error;
   $np->nagios_die( "could not get update info from $rrdfile: $ERR") if $ERR;

   # -- calculate time difference
   my $current_time = strftime("%s", localtime());
   my $time_diff = $current_time - $lastupdate;
   print "time diff = $time_diff \n" if ($debug);
   
   # -- check thresholds
   $result = $np->check_threshold($time_diff);
   # -- perfdata
   $performance_label = ( defined($performance_label)) ? $performance_label : 'age';
   $np->add_perfdata( label    => $performance_label,
		      value    => $time_diff,
		      uom      => 's',
		      warning  => $np->opts->warning,
		      critical => $np->opts->critical,
		    );
   # -- exit and info
   $text_label = ( defined($text_label)) ? $text_label : 'AGE';
   $np->nagios_exit( return_code => $result,
                     message     => "$text_label $time_diff seconds old"
                   );

}

# ----------------------------------------
# mode = cf (should be)
# ----------------------------------------

if ( "$mode" ne "cf" ) {
   $np->nagios_die("unknown mode $mode, should be cf, info or age");
}

if ((! defined ($np->opts->ds)) || ($np->opts->ds eq "")) {
   $np->nagios_die('No data source specified! Use --info to list data source names of the rrd file and --ds to specify data source.');
}

if ($debug) {
   print "DEBUG: --start ".$np->opts->start." --end ".$np->opts->end." --resolution ".$np->opts->resolution."\n";
}

# -- fetch data and info
($fetch_start, $fetch_step, $fetch_dsnames, $fetch_data) 
= RRDs::fetch("$rrdfile", $np->opts->cf, "--start", $np->opts->start,
	      "--end", $np->opts->end, "--resolution", $np->opts->resolution);

# -- error handling
my $ERR=RRDs::error;
$np->nagios_die( "could not fetch data from $rrdfile: $ERR") if $ERR;


# -- data sources
for ( my $i = 0; $i <= $#$fetch_dsnames; $i++ ) {
   if ( "$$fetch_dsnames[$i]" eq $np->opts->ds ) {
      $ds_index = $i;
      last;
   }
}
if ( $ds_index == -1 ) {
   $np->nagios_die( "data source ".$np->opts->ds." not found in $rrdfile" );
}
if ($debug) {
   print "DEBUG: data source index is $ds_index\n";
}
# -- get data column
my @ds_values = ();
my $start_t = $fetch_start;

foreach my $line ( @$fetch_data ) {
   my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime($start_t));
   my $value     = $$line[$ds_index];

   if ( defined($value) ) {
      push @ds_values, $value;
   }
   else {
      $value = "no value";
      $notavailable +=1;
   }

   if ($debug) {
      print "DEBUG: [$timestamp] - $value\n";
   }
   $start_t += $fetch_step;
}
if ($debug) {
   my $length = $#ds_values + 1;
   print "DEBUG: ds_values: $length values found + $notavailable N/A\n";
}

# ----------------------------------------
# exit with na_values_returncode if @ds_values has no content

if ( $#ds_values < 0 ) {
   $result = $np->opts->na_values_returncode;
   $text_label = ( defined($text_label)) ? $text_label : '';
   $np->nagios_exit( return_code => $result,
		     message     => "$text_label no valid values found in $rrdfile"
		   );
}

# ----------------------------------------
# compute = MIN, MAX, AVERAGE

my @sorted = ();
my $computed;

COMPUTE: {
   if ( ! grep /^$compute$/, ('MIN', 'MAX', 'AVERAGE') ) {
      last COMPUTE;
   }
   if ( $np->opts->compute eq 'MIN' ) {
      @sorted = sort { $a <=> $b } @ds_values;
      $computed = shift @sorted;
   }
   if ( $np->opts->compute eq 'MAX' ) {
      @sorted = sort { $b <=> $a } @ds_values;
      $computed = shift @sorted;
   }
   if ( $np->opts->compute eq 'AVERAGE' ) {
      my $sum = 0;
      foreach my $val ( @ds_values ) {
         $sum += $val;
      }
      $computed = $sum / ($#ds_values + 1);
   }
   if ( defined( $np->opts->round ) ) {
   	   $computed = nearest( $np->opts->round, $computed );
   }
   # -- check thresholds
   $result = $np->check_threshold($computed);
   print "DEBUG: Result is $result (".$STATUS_TEXT{$result}.")\n" if ($debug);
   
   # -- do we have na values?
   if ( $notavailable ) {
      $result = ($result >= $na_values_returncode) ? $result : $na_values_returncode;
      #$result = $np->opts->na_values_returncode;
      print "DEBUG: N/A Values! Set result to $result (".$STATUS_TEXT{$result}.")\n" if ($debug);
   }
   
   # -- perfdata
   $performance_label = ( defined($performance_label)) 
		      ? $performance_label 
		      : $np->opts->ds . "." . $np->opts->cf . "." . lc($np->opts->compute)
		      ;
   $np->add_perfdata( label    => $performance_label,
		      value    => $computed,
		      warning  => $np->opts->warning,
		      critical => $np->opts->critical,
		    );
   # -- exit and info
      $text_label = defined($text_label) ? $text_label : $np->opts->compute;
   $np->nagios_exit( return_code => $result,
		     message     => "$text_label: $computed"
		   );

} # end COMPUTE

# ----------------------------------------
# compute = PERCENT

my $sum_all = $#ds_values + 1 + $notavailable;
my $sum_ok  = ($na_values_returncode == 0) ? $notavailable : 0;

foreach my $val ( @ds_values ) {
   # -- check thresholds
   my $what = $np->check_threshold($val);
   print "DEBUG: percent: $val -> $what (".$STATUS_TEXT{$what}.")\n" if ($debug); 
   $sum_ok += 1 unless ($what);
}

my $percent_ok = ($sum_ok/$sum_all) * 100;

if ( defined( $np->opts->round ) ) {
   $computed = nearest( $np->opts->round, $percent_ok );
}

# -- check thresholds
$result = $np->check_threshold($percent_ok);
# -- perfdata
$performance_label = ( defined($performance_label)) 
                   ? $performance_label 
		   : $np->opts->ds . "." . $np->opts->cf . "." . lc($np->opts->compute)
		   ;
$np->add_perfdata( label    => $performance_label,
		   value    => $percent_ok,
		   uom	    => '%',
		   warning  => $np->opts->clip_warn_level,
		   critical => $np->opts->clip_crit_level,
		 );
# -- exit and info
$text_label = ( defined($text_label)) ? $text_label : 'Values ok: ';
$np->nagios_exit( return_code => $result,
		  message     => "$text_label $percent_ok%"
		);

