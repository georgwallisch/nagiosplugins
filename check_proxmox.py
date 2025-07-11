#!/usr/bin/python3
# -*- coding: utf-8 -*-

""" This is a monitoring plugin for Proxmox PVE
"""

__author__ = "Georg Wallisch"
__contact__ = "gw@phpco.de"
__copyright__ = "Copyright © 2025 by Georg Wallisch"
__credits__ = ["Georg Wallisch"]
__date__ = "2025/07/11"
__deprecated__ = False
__email__ =	 "gw@phpco.de"
__license__ = "open source software"
__maintainer__ = "Georg Wallisch"
__status__ = "alpha"
__version__ = "0.1"
__doc__= "Proxmox PVE monitoring plugin"


import argparse
import sys, os
from proxmoxer import ProxmoxAPI
import nagiosplugin
import logging


logging.basicConfig(stream=sys.stdout, encoding='utf-8')
_log = logging.getLogger(__name__)
LOG_LEVELS = ["CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"]


class ProxmoxContext(nagiosplugin.Context):
	def __init__(self, name, fmt_metric=None, result_cls=nagiosplugin.Result):
	 	 super(ProxmoxContext, self).__init__(name, fmt_metric, result_cls)

	def performance(self, metric, ressource):
		return None

	def evaluate(self, metric, resource):		
		
		if metric.value is None:
			_log.debug('Metric value is NONE!')
			return self.result_cls(nagiosplugin.Unknown, None, metric)
		elif self.name == 'subscription_status':
			if metric.value == "Active":			
				_log.debug('Subscription seems to be active')
				return self.result_cls(nagiosplugin.Ok, None, metric)
			elif metric.value == "notfound":
				_log.debug('There is no active subscription!')
				return self.result_cls(nagiosplugin.Warn, None, metric)
			else:
				_log.debug('Dunno what subscription status is!')
				return self.result_cls(nagiosplugin.Unknown, None, metric)
		elif self.name == 'node_status':
			if metric.value == 1:
				_log.debug('Node seems to be online')
				return self.result_cls(nagiosplugin.Ok, None, metric)
			else:
				_log.debug('Node seems to be offline!')
				return self.result_cls(nagiosplugin.Crit, None, metric)
		elif self.name == 'service_status':
			if metric.value == 1:
				_log.debug('Service seems to be online')
				return self.result_cls(nagiosplugin.Ok, None, metric)
			else:
				_log.debug('Service seems to be offline!')
				return self.result_cls(nagiosplugin.Crit, None, metric)
			
		_log.debug('Dunno what metric is all about?!')
		return self.result_cls(nagiosplugin.Unknown, None, metric)

class Proxmox(nagiosplugin.Resource):
	
	def __init__(self, host, username, password, node, verify_ssl=False):
				
		self.node = node
		self.host = host										  
		self.username = username
		self.password = password
		self.verify_ssl = verify_ssl
		
		_log.debug('Host: %s', self.host)
		_log.debug('User (Pw): %s (%a)', self.username, self.password)
		_log.debug('Node: %s', self.node)
		_log.debug('verify_ssl is set to %s', self.verify_ssl)
		
		try:
			self.proxmox = ProxmoxAPI(self.host, user=self.username, password=self.password, verify_ssl=self.verify_ssl)
		except Exception as e:
			print("ProxmoxAPI error: {0}".format(e))
			raise
		
	def list_nodes(self):
		nodes = []
		for s in self.proxmox.nodes.get():
			nodes.append(s['node'])
		return nodes
		
	def list_services(self):
		services = []
		for s in self.proxmox.nodes(self.node).services.get():
			services.append(s['name'])
		return services
		
	def probe(self):
		_log.info('Checking status of node: %s', self.node)
		for s in self.proxmox.cluster.status.get():
			_log.debug('Getting node: %s', s['name'])
			if s['name'] == self.node:
				return [nagiosplugin.Metric('node_status', s['online'])]
		_log.debug('Node %s not found!', self.node)
		return [nagiosplugin.Metric('node_status', None)]
		
class ProxmoxService(Proxmox):
	
	def __init__(self, host, username, password, node, service, verify_ssl=False):
		self.service = service
		super().__init__(host, username, password, node, verify_ssl)
		
	def probe(self):
		_log.info('Checking status of service: %s', self.service)
		for s in self.proxmox.nodes(self.node).services.get():
			if s['name'] == self.service:
				_log.debug('Status of service %s is %s', s['name'], s['state'])
				return [nagiosplugin.Metric('service_status', s['online'])]
		_log.debug('Service %s not found!', self.service)
		return [nagiosplugin.Metric('service_status', None)]		
					
class ProxmoxMemoryUsage(Proxmox):
	
	def __init__(self, host, username, password, node, verify_ssl=False):
		super().__init__(host, username, password, node, verify_ssl)
		
	def probe(self):
		for i in self.proxmox.cluster.resources.get():
			if i['type'] == "node":
				_log.debug('Getting node: %s', i['node'])
				if i['node'] == self.node:
					_log.debug('Memory raw value: %i', i['mem'])
					_log.debug('Memory max value: %i', i['maxmem'])
					mem = round(i['mem'] / (1024 * 1024), 1)
					pct = round(i['mem'] / i['maxmem'] * 100, 2)
					_log.debug('Memory rate is: %f', pct)
					return [nagiosplugin.Metric('mem_usage_total', mem, uom='MiB', min=0, context='memory_usage'),
						nagiosplugin.Metric('mem_usage_rate', pct, uom='%', min=0, context='memory_usage')] 
		
class ProxmoxSubscription(Proxmox):
	
	def __init__(self, host, username, password, node, verify_ssl=False):
		super().__init__(host, username, password, node, verify_ssl)
		
	def probe(self):
		_log.info('Checking subscription status of node: %s', self.node)
		sub_status = self.proxmox.nodes(self.node).subscription.get()['status']
		_log.debug('Subscription status is: %s', sub_status)
		return [nagiosplugin.Metric('subscription_status', sub_status)]

@nagiosplugin.guarded
def main():
	try:
		argp = argparse.ArgumentParser(description=__doc__)
		
		argp.add_argument('-H', '--host', metavar='ADDRESS', required=True, help='Proxmox host name or IP Address')
		argp.add_argument('-N', '--node', metavar='NODENAME', required=True, help='Proxmox node name (e.g. \'pmx\' or \'pve\')')
		argp.add_argument('-u', '--username', metavar='USER', default='root@pam', help='Proxmox user name')
		argp.add_argument('-p', '--password', metavar='PASSWD', required=True, help='User\'s password')
		argp.add_argument('-m', '--mem-usage', action='store_true', help='Check memory usage of NODE')
		argp.add_argument('-w', '--warning', metavar='RANGE', default='', help='Return warning if value is outside RANGE')
		argp.add_argument('-c', '--critical', metavar='RANGE', default='', help='return critical if value is outside RANGE')
		argp.add_argument('-t', '--timeout', metavar='SECONDS', default='10', help='Seconds before connection times out (default: 10)')
		argp.add_argument('-S', '--verify-ssl', action='store_true', help='Only use if you have set up valid SSL certificates')
		argp.add_argument('-s', '--service', metavar='NAME', help='Check status of SERVICE')
		argp.add_argument('-b', '--sub-status', action='store_true', help='Check Proxmox subscription status')
		argp.add_argument('-v', '--verbose', action='count', default=0, help='increase output verbosity (use up to 3 times)')
		argp.add_argument('-l', '--list-nodes', action='store_true', help='List all nodes')
		argp.add_argument('-z', '--list-services', action='store_true', help='List all services')

		args = argp.parse_args()
		
		loglevel = min(args.verbose, len(LOG_LEVELS)-1)
		_log.setLevel(LOG_LEVELS[loglevel])
				
		_log.debug("Verbosity is set to {0}".format(args.verbose))
		_log.info("Log Level is set to {0} ({1})".format(loglevel, LOG_LEVELS[loglevel]))
		_log.info("Timeout is set to {0}".format(args.timeout))
		
		if args.list_nodes:
			l = Proxmox(args.host, args.username, args.password, args.node, args.verify_ssl).list_nodes()
			print("\nList of all nodes on {0}:\n".format(args.host))
			for e in l:
				print("* {0}".format(e))
			print("\nThat's it!")
			sys.exit(0)
		
		if args.list_services:
			l = Proxmox(args.host, args.username, args.password, args.node, args.verify_ssl).list_services()
			print("\nList of all Services on {0}:\n".format(args.host))
			for e in l:
				print("* {0}".format(e))
			print("\nThat's it!")
			sys.exit(0)
	
		if args.service:
			check = nagiosplugin.Check(ProxmoxService(args.host, args.username, args.password, args.node, args.service, args.verify_ssl), ProxmoxContext('service_status'))
		elif args.mem_usage:
			check = nagiosplugin.Check(ProxmoxMemoryUsage(args.host, args.username, args.password, args.node, args.verify_ssl), nagiosplugin.ScalarContext('memory_usage', args.warning, args.critical, fmt_metric='Memory usage of node {0}'.format(args.node)))
		elif args.sub_status:
			check = nagiosplugin.Check(ProxmoxSubscription(args.host, args.username, args.password, args.node, args.verify_ssl), ProxmoxContext('subscription_status')) 
		else:
			check = nagiosplugin.Check(Proxmox(args.host, args.username, args.password, args.node, args.verify_ssl), ProxmoxContext('node_status'))
			
		check.main(args.verbose, args.timeout)

																	   
	except KeyboardInterrupt:
		print("\nAbbruch durch Benutzer Ctrl+C")
	except TypeError as e:
		exc_type, exc_obj, exc_tb = sys.exc_info()
		print("Type Error: {0} in line {1}".format(e, exc_tb.tb_lineno))
	except RuntimeError as e:
		print("RuntimeError: ",e)
	except Exception as e:
		exc_type, exc_obj, exc_tb = sys.exc_info()
		fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
		print("Unexpected error {0}: {1} in {2} line {3}".format(exc_type, e, fname, exc_tb.tb_lineno))
#	finally:
#		print("Finally ended")


if __name__ == '__main__':
	main()