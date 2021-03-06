#!/usr/bin/python
# -*- coding: utf-8 -*-

""" This is an monitoring system for pharmacies.
"""

__author__ = "Georg Wallisch"
__contact__ = "gw@phpco.de"
__copyright__ = "Copyright © 2019 by Georg Wallisch"
__credits__ = ["Georg Wallisch"]
__date__ = "2019/09/07"
__deprecated__ = False
__email__ =  "gw@phpco.de"
__license__ = "open source software"
__maintainer__ = "Georg Wallisch"
__status__ = "alpha"
__version__ = "0.3"


import re, os, rrdtool, time, sys
import argparse
import logging
import locale

_log = logging.getLogger('cputemp')

def read_cputemp():
	try:
		temp = None
		with open('/sys/class/thermal/thermal_zone0/temp', 'r') as tempfile:
			data = tempfile.readline()
			_log.debug("Raw Value: {0}".format(data))
			if len(data) > 3:
				temp = int(data) / 1000.0
				
		return temp
	
	except Exception as e:
		exc_type, exc_obj, exc_tb = sys.exc_info()
		fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
		_log.error("Unexpected error: ",exc_type, fname, exc_tb.tb_lineno)
		
def update_rrd(rrdfile):
	t = read_cputemp()
	if t is not None:
		data = "N:{0:0.1f}".format(t)	
		rrdtool.update(rrdfile, data)
		return t

def main():
	try:
		argp = argparse.ArgumentParser(description=__doc__)
		argp.add_argument('rrdfile',
						  help='The name of the RRD to use.')
		argp.add_argument('-S', '--step', default=100, type=int,
						  help='Interval in seconds with which data will be fed into the RRD (default: 100 seconds). Will be used when creating a new RRD and as loop delay on continous reading.')
		argp.add_argument('-C','--create', action="store_true",
						  help='create new round-robin database')
		argp.add_argument('-c','--continuous', action="store_true",
						  help='Continuously reading system temperature and storing to rrd. Using --step as loop delay.')		
		argp.add_argument("-q", "--quiet", action="store_true",
			 			  help='Quiet mode. No output.')
		argp.add_argument('-v', '--verbose', action='count', default=0,
					  help='Increase output verbosity.')
		argp.add_argument('-l', '--locale', default="de_DE",
						  help='Set time locale for logging output')
#		argp.add_argument('--read-test', action="store_true",
#						  help='just read cpu temp until Ctrl+C without using a RRD anyway.')
		args = argp.parse_args()

		if args.quiet:
			logging.basicConfig(level=99)
		elif args.verbose > 1:
			logging.basicConfig(level=logging.DEBUG)
		elif args.verbose == 1:
			logging.basicConfig(level=logging.INFO)
		else:
			logging.basicConfig(level=logging.WARNING)
		#else:			
		#	logging.basicConfig(level=logging.ERROR)
		
		locale.setlocale(locale.LC_TIME, args.locale)
		_log.info("Locale is set to {0}".format(locale.getlocale(locale.LC_TIME)))

		if args.step > 300:
			_log.warning("Step size {0} is too large! Reducing to maximum of 300 seconds.".format(args.step))
			step = 300
		elif args.step < 10:
			_log.warning("Step size {0} is too small! In order not to poll thermal data file too often producing too much system load setting step size to minimum of 10 seconds.".format(args.step))
			step = 10
		else:
			_log.warning("Step size is set to {0} seconds.".format(args.step))
			step = args.step
			
		if args.create:
			if os.path.isfile(args.rrdfile):
				print("Cannot create {0}".format(args.rrdfile))
				print("Already exists!")
			else:
				a = int(round(300 / step))
				print("Creating {0} using a step size of {1} seconds..".format(args.rrdfile, str(step)))
				rrdtool.create(
					args.rrdfile,
					"--step", str(step),
					"DS:temp:GAUGE:{0}:-20:110".format(step*2),
					# aggregate data points of 5 minutes and save for 24h
					"RRA:AVERAGE:0.5:{0}:288".format(a),
					"RRA:MIN:0.5:{0}:288".format(a),
					"RRA:MAX:0.5:{0}:288".format(a),
					# aggregate data points of 1 hour and save for 30 days
					"RRA:AVERAGE:0.5:{0}:720".format(a*12),
					"RRA:MIN:0.5:{0}:720".format(a*12),
					"RRA:MAX:0.5:{0}:720".format(a*12),
					# aggregate data points of 1 day and save for 1 year
					"RRA:AVERAGE:0.5:{0}:365".format(a*288),
					"RRA:MIN:0.5:{0}:365".format(a*288),
					"RRA:MAX:0.5:{0}:365".format(a*288))
				print("Done.")
#		elif args.read_test:
#			print("Start reading...")
#			while True:
#				print("{0} °C".format(read_cputemp()))
#				time.sleep(5)		
		else:
			if os.path.isfile(args.rrdfile):
				
				if args.continuous:
					_log.info("Starting continuous reading system temperatue every {0} seconds".format(step))
					while True:
						t = update_rrd(args.rrdfile)
						if t is not None:
							_log.info("{0}: {1} °C".format(time.strftime("%x %X"),t))
						else:
							_log.info("{0}: ---".format(time.strftime("%x %X")))
						time.sleep(step)
				else:
					t = update_rrd(args.rrdfile)
					print("Just once reading system temperatue: {0} °C".format(t))
					
			else:
				_log.error("Cannot access {0}! File does not exist!".format(args.rrdfile))


	except KeyboardInterrupt:
		print("\nAbbruch durch Benutzer Ctrl+C")
	except TypeError as e:
		exc_type, exc_obj, exc_tb = sys.exc_info()
		_log.error("Type Error: {0} in line {1}".format(e, exc_tb.tb_lineno))
	except RuntimeError as e:
		_log.error("RuntimeError: ",e)
	except Exception as e:
		exc_type, exc_obj, exc_tb = sys.exc_info()
		fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
		_log.error("Unexpected error {0}: {1} in {2} line {3}".format(exc_type, e, fname, exc_tb.tb_lineno))
	finally:
		print("Finally ended")

if __name__ == '__main__':
	main()