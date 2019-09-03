#!/usr/bin/python
# -*- coding: utf-8 -*-

""" This is an monitoring system for pharmacies.
"""

__author__ = "Georg Wallisch"
__contact__ = "gw@phpco.de"
__copyright__ = "Copyright © 2019 by Georg Wallisch"
__credits__ = ["Georg Wallisch"]
__date__ = "2019/09/03"
__deprecated__ = False
__email__ =  "gw@phpco.de"
__license__ = "open source software"
__maintainer__ = "Georg Wallisch"
__status__ = "alpha"
__version__ = "0.1"


import re, os, rrdtool, time, sys
import argparse

def read_cputemp():
	try:
		temp = None
		with open('/sys/class/thermal/thermal_zone0/temp', 'r') as tempfile:
			data = tempfile.readline()
			if len(data) > 3:
				temp = int(data) / 1000.0
				
		return temp
#	
#		if humidity is not None and temperature is not None:
#			data = "N:{0:0.1f}:{1:0.1f}".format(temperature, humidity)
#			rrdtool.update(raum_rrd, data)
#			print time.strftime("%x %X"), ' Temp={0:0.1f}°C  Humidity={1:0.1f}%'.format(temperature, humidity)
#		else:
#			print time.strftime("%x %X"), "Error reading DHT22"
	
	except Exception as e:
		exc_type, exc_obj, exc_tb = sys.exc_info()
		fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
		print("Unexpected error: ",exc_type, fname, exc_tb.tb_lineno)

def main():
	try:
		argp = argparse.ArgumentParser(description=__doc__)
		argp.add_argument('-d', '--rrd', default='cputemp.rrd',
						  help='Round Robin Database to write data')
		argp.add_argument('--create', default='',
						  help='create new round-robin database')
		argp.add_argument('--read-test', action="store_true",
						  help='just read cpu temp until Ctrl+C')
		args = argp.parse_args()
#		rrd_path = os.path.abspath(os.path.join(os.path.dirname(__file__),'..','rrd'))
#		raum_rrd = os.path.join(rrd_path, 'apo_raum1.rrd')

		if args.read_test:
			print("Start reading...")
			while True:
				print("{0} °C".format(read_cputemp()))
				time.sleep(5)
		else:
			print("Nothing to do..")


	except KeyboardInterrupt:
		print("\nAbbruch durch Benutzer Ctrl+C")
	except RuntimeError as e:
		print("RuntimeError: ",e)
	except Exception as e:
		exc_type, exc_obj, exc_tb = sys.exc_info()
		fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
		print("Unexpected error: ",exc_type, fname, exc_tb.tb_lineno)
	finally:
		print("Finally ended")

if __name__ == '__main__':
	main()