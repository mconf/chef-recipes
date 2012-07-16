#!/usr/bin/python

import sys
import os
if os.name != 'posix':
    sys.exit('platform not supported')
os.environ['PATH'] += ':/usr/bin:/sbin:/bin'
import atexit
import time
import commands
import re
import string
import argparse
import psutil
from threading import Thread
from daemon import Daemon
import json

# Exit statuses recognized by Nagios
NAGIOS_OK = 0
NAGIOS_WARNING = 1
NAGIOS_CRITICAL = 2
NAGIOS_UNKNOWN = 3

def toKbps(n):
    return float(n >> 7)
    
def byte_to_bit(n):
    return n << 3

def trunc(f, n):
    '''Truncates/pads a float f to n decimal places without rounding'''
    slen = len('%.*f' % (n, f))
    return str(f)[:slen]

class CircularList:
    def __init__(self, size):
        self.list = []
        self.max_size = size
        
    def append(self, data):
        self.list = [data] + self.list[:self.max_size - 1]
        
    def avg(self):
        return sum(self.list) / float(len(self.list))
    
class processesAnalyzer(Thread):
    '''collect cpu process data and print them to the stdout'''
    def __init__ (self,refreshRate):
        Thread.__init__(self)
        self.refreshRate = refreshRate
        self.terminate = False
    
    def kill(self):
        self.terminate = True
        
    def run(self):
        while True:
            if self.terminate:
                return
            processList = []
            for p in psutil.process_iter():
                processList.append(p)
            try:
                processesSortByMem = sorted(processList, key=lambda p: p.get_memory_percent(), reverse=True)
                processesSortByProc = sorted(processList, key=lambda p: p.get_cpu_percent(interval=0), reverse=True)
                #to use later. Print top 5 processes on mem and proc usage
                printProcStatus = False
                if printProcStatus:
                    print "sorted by memory usage"
                    for i, p in zip(range(5),processesSortByMem):
                        print (" process name: " + str(p.name) + " mem use: " + str(p.get_memory_percent()))
                    print "\n"
                    print "sorted by processor usage"
                    for i, p in zip(range(5),processesSortByProc):
                        print (" process name: " + str(p.name) + " proc use: " + str(p.get_cpu_percent(interval=0)))
                    print "\n\n\n\n\n\n\n\n"
            except psutil.NoSuchProcess:
                #just to catch the error and avoid killing the thread
                #the raised error is because the process maybe killed before the get_cpu_percent or get_memory_percent calls
                pass
            time.sleep(self.refreshRate)

    

class Sender(Thread):
    def __init__(self, config, reporters):
        Thread.__init__(self)
        self.config = config
        self.reporters = reporters
        self.terminate = False

    def kill(self):
        self.terminate = True

    def threadLoop(self):
        for reporter in self.reporters:
            service = reporter.service
            message, state = reporter.data()
            self.__sendReport(service, state, message)
    
    def run(self):
        while not self.terminate:
            time.sleep(self.config.send_rate)
            self.threadLoop()
    
    def __sendReport(self, service, state, message):
        '''send report to nagios server'''
        #mount data 
        send_nsca_dir = "/usr/local/nagios/bin"
        send_nsca_cfg_dir = "/usr/local/nagios/etc"
        command = (
            "/usr/bin/printf \"%s\t%s\t%s\t%s\n\" \"" 
            + self.config.hostname + "\" \"" 
            + service + "\" \"" 
            + str(state) + "\" \"" 
            + message + "\" | " 
            + send_nsca_dir + "/send_nsca -H " 
            + self.config.nagios_server + " -c " 
            + send_nsca_cfg_dir + "/send_nsca.cfg")
        commandoutput = commands.getoutput(command)
        if self.config.debug:
            print "---------------------------------"
            print service, state, message
            print command

class Reporter(Thread):
    '''base reporter thread class'''
    def __init__ (self, config):
        Thread.__init__(self)
        self.terminate = False
        self.config = config
        self.minimum = 0
        self.maximum = None
    
    def kill(self):
        #send kill sign to terminate the thread in the next data collection loop
        self.terminate = True
        
    def threadLoop(self):
        #nothing on the base class 
        #Should be implemented by each reporter service and set the self.state and self.message variables
        return
            
    def run(self):
        while not self.terminate:
            #call method that actually do what the threads needs to do
            self.threadLoop()

    def formatMessage(self, data, label, unit):
        list_avg = data.avg()
        list_max = max(data.list)
        list_min = min(data.list)
        if self.maximum == None:
            format = "%s_%%s=%%.2f%s;%d;%d;%d; " % (label, unit.replace("%", "%%"), self.warning, self.critical, self.minimum)
        else:
            format = "%s_%%s=%%.2f%s;%d;%d;%d;%d " % (label, unit.replace("%", "%%"), self.warning, self.critical, self.minimum, self.maximum)
        return format % ("avg", list_avg) + format % ("max", list_max) + format % ("min", list_min)
    
    def checkStatus(self, data):
        if data >= self.critical:
            return NAGIOS_CRITICAL
        elif data >= self.warning:
            return NAGIOS_WARNING
        else:
            return NAGIOS_OK
        
class MemoryReporter(Reporter):
    '''reporter class to collect and report memory data'''
    def __init__(self, config):
        Reporter.__init__(self, config)
        self.service = "Memory Report"
        self.list = CircularList(self.config.send_rate)
        self.maximum = psutil.phymem_usage().total / (1024 * 1024)
        self.warning = (self.config.memory_warning * self.maximum) / 100
        self.critical = (self.config.memory_critical * self.maximum) / 100
        
    def threadLoop(self):
        time.sleep(1)
        #self.list.append(psutil.phymem_usage().used / (1024 * 1024))
        self.list.append((psutil.phymem_usage().percent * self.maximum) / 100)
    
    def data(self):
        # message mount
        list_avg = self.list.avg()
        message = "Memory usage: %dMB of %dMB (%d%%)" % (list_avg, \
            self.maximum, (list_avg * 100) / self.maximum) \
            + "|" + self.formatMessage(self.list, "mem", "MB")
        # state mount
        state = self.checkStatus(list_avg)
        return message, state

class DiskReporter(Reporter):
    def __init__(self, config):
        Reporter.__init__(self, config)
        self.service = "Disk Report"
        self.list = CircularList(self.config.send_rate)
        self.maximum = psutil.disk_usage('/').total / (1024 * 1024 * 1024)
        self.warning = (self.config.disk_warning * self.maximum) / 100
        self.critical = (self.config.disk_critical * self.maximum) / 100
    
    def threadLoop(self):
        time.sleep(1)
        self.list.append((psutil.disk_usage('/').percent * self.maximum) / 100)
        
    def data(self):
        list_avg = self.list.avg()
        # message mount
        message = "Disk usage: %dGB of %dGB (%d%%)" % (list_avg, \
            self.maximum, (list_avg * 100) / self.maximum) \
            + "|" + self.formatMessage(self.list, "disk", "GB")
        # state mount
        state = self.checkStatus(list_avg)
        return message, state

class ProcessorReporter(Reporter):
    '''reporter class to collect and report processor data'''
    def __init__ (self,config):
        Reporter.__init__(self, config)
        self.service = "Processor Report"
        self.list = CircularList(self.config.send_rate)
        self.maximum = 100
        self.warning = self.config.cpu_warning
        self.critical = self.config.cpu_critical
        self.processor = commands.getoutput("cat /proc/cpuinfo | grep 'model name' | head -n 1 | sed 's:.*\: *\(.*\):\\1:g' | sed 's/  */\ /g'")
        
    def threadLoop(self):
        self.list.append(psutil.cpu_percent(1, percpu=False))
    
    def data(self):
        list_avg = self.list.avg()
        # message mount
        message = "CPU usage: %.1f%% Model: %s" % (list_avg, self.processor) \
            + "|" + self.formatMessage(self.list, "cpu", "%")
        # state mount
        state = self.checkStatus(list_avg)
        return message, state

class NetworkReporter(Reporter):
    '''reporter class to collect and report network data'''
    def __init__(self, config):
        Reporter.__init__(self, config)
        self.service = "Network Report"
        self.sent = CircularList(self.config.send_rate)
        self.recv = CircularList(self.config.send_rate)
        self.warning = self.config.network_warning * 1000 # in Mbit/s
        self.critical = self.config.network_critical * 1000 # in Mbit/s
        
    def threadLoop(self):
        pnic_before = psutil.network_io_counters(pernic=True)
        
        if not pnic_before.has_key(self.config.network_interface):
            print "Couldn't find the network interface %s" % (self.config.network_interface)
            self.config.network_interface = None
            for i in pnic_before.keys():
                if i != "lo":
                    self.config.network_interface = i
                    break
            if self.config.network_interface == None:
                return
            print "Using %s instead" % (self.config.network_interface)
        stats_before = pnic_before[self.config.network_interface]
 
        while not self.terminate:
            time.sleep(1)
            
            pnic_after = psutil.network_io_counters(pernic=True)
            stats_after = pnic_after[self.config.network_interface]

            # format bytes to string
            bytesSent = byte_to_bit(stats_after.bytes_sent - stats_before.bytes_sent) #toKbps(stats_after.bytes_sent - stats_before.bytes_sent) / 1
            bytesReceived = byte_to_bit(stats_after.bytes_recv - stats_before.bytes_recv) #toKbps(stats_after.bytes_recv - stats_before.bytes_recv) / 1

            # store on a circular list
            self.sent.append(bytesSent)
            self.recv.append(bytesReceived)
            stats_before = stats_after
            
    def normalize(self, value):
        if value >= 1000000000:
            return (value / 1000000000, "Gbit/s")
        elif value >= 1000000:
            return (value / 1000000, "Mbit/s")
        elif value >= 1000:
            return (value / 1000, "kbit/s")
        else:
            return (value, "bit/s")

    def data(self):
        sent_avg, sent_unit = self.normalize(self.sent.avg())
        recv_avg, recv_unit = self.normalize(self.recv.avg())
        # message mount
        message = "Network bandwidth used: up %.1f%s - down %.1f%s" \
            % (sent_avg, sent_unit, recv_avg, recv_unit) + " |" \
            + self.formatMessage(self.sent, "sent", "") \
            + self.formatMessage(self.recv, "recv", "")
        # state mount
        state = max(int(self.checkStatus(self.sent)), int(self.checkStatus(self.recv)))
        return message, state

def parse_args():
    parser = argparse.ArgumentParser(description = "Fetches information for a Performance Reporter")
    parser.add_argument("--network_interface",
        required = False,
        help = "network interface to be monitored",
        dest = "network_interface",
        default = "eth0",
        metavar = "<network_interface>")
    parser.add_argument("--hostname",
        required = False,
        help = "name of the caller host",
        dest = "hostname",
        default = "`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`",
        metavar = "<hostname>")
    parser.add_argument("--send_rate",
        required = False,
        help = "set the interval in which the script will send data to the Nagios server, in seconds",
        dest = "send_rate",
        default = "60",
        metavar = "<send_rate>")
    parser.add_argument("--server",
        required = True,
        help = "IP address of the Nagios server",
        dest = "nagios_server",
        metavar = "<nagios_server>")
    parser.add_argument("--debug",
        required = False,
        help = "debug mode: print output",
        dest = "debug",
        action = "store_true")
    parser.add_argument("--network-warning", required=False, default="70000",
        help="define the warning limit in kbps", dest="network_warning", 
        metavar="<network_warning>")
    parser.add_argument("--network-critical", required=False, default="90000", 
        help="define the critical limit in kbps", dest="network_critical", 
        metavar="<network_critical>")
    parser.add_argument("--cpu-warning", required=False, default="90", 
        help="define the warning limit in %", dest="cpu_warning", 
        metavar="<cpu_warning>")
    parser.add_argument("--cpu-critical", required=False, default="100", 
        help="define the critical limit in %", dest="cpu_critical", 
        metavar="<cpu_critical>")
    parser.add_argument("--memory-warning", required=False, default="70", 
        help="define the warning limit in %", dest="memory_warning", 
        metavar="<memory_warning>")
    parser.add_argument("--memory-critical", required=False, default="90", 
        help="define the critical limit in %", dest="memory_critical", 
        metavar="<memory_critical>")
    parser.add_argument("--disk-warning", required=False, default="80", 
        help="define the warning limit in %", dest="disk_warning", 
        metavar="<disk_warning>")
    parser.add_argument("--disk-critical", required=False, default="90", 
        help="define the critical limit in %", dest="disk_critical", 
        metavar="<disk_critical>")
    return parser.parse_args()

class Configuration:
    def __init__(self, args):
        self.debug = args.debug
        self.network_interface = args.network_interface
        self.hostname = args.hostname
        self.nagios_server = args.nagios_server
        self.send_rate = int(args.send_rate)
        self.network_warning = int(args.network_warning)
        self.network_critical = int(args.network_critical)
        self.cpu_warning = int(args.cpu_warning)
        self.cpu_critical = int(args.cpu_critical)
        self.memory_warning = int(args.memory_warning)
        self.memory_critical = int(args.memory_critical)
        self.disk_warning = int(args.disk_warning)
        self.disk_critical = int(args.disk_critical)

class Runner:
    def __init__(self):
        '''main loop to call all the reporters'''
        self.running = False
        
    def start(self, args):
        if self.running:
            return
            
        config = Configuration(args)
        
        self.threadsList = []
        # here we should have the main call to the reporter threads
        self.threadsList.append(NetworkReporter(config))
        self.threadsList.append(ProcessorReporter(config))
        self.threadsList.append(MemoryReporter(config))
        self.threadsList.append(DiskReporter(config))
#        threadsList.append(processesAnalyzer(config))

        self.sender = Sender(config, self.threadsList)
        # start every thread
        for reporterThread in self.threadsList:
            reporterThread.start()
        self.sender.start()
        self.running = True

    def stop(self):
        if not self.running:
            return
            
        # send kill sign to all threads
        self.sender.kill()
        self.sender.join()
        for reporterThread in self.threadsList:
            reporterThread.kill()
        # wait for each thread to finish
        for reporterThread in self.threadsList:
            reporterThread.join()
        self.running = False

class WSDaemon(Daemon):  
    def __init__(self, *kwargs):
        self.__filename__ = '/tmp/performance_report.cfg'
        return super(WSDaemon, self).__init__(*kwargs)
        
    def start(self):
        if len(sys.argv) <= 1:
            self.__reuse_config__ = False
            print "Trying to read parameters from file"
            try:
                sys.argv = self.__readFile__()
                print "Reusing the following arguments: %s" % (sys.argv)
            except:
                print "Failed to recover the lastest used configurations"
        self.args = sys.argv
        self.parsed_args = parse_args()
        return super(WSDaemon, self).start()
    
    def run(self):
        self.runner = Runner()
        self.__writeFile__(self.args)
        self.runner.start(self.parsed_args)
        
    def __writeFile__(self, data):
        # writes the data as a JSON-encoded dict
        f = open(self.__filename__, 'w')
        filestring = json.dumps(data) + '\n'
        f.write(filestring)
        f.close()

    def __readFile__(self):
        # reads a JSON-encoded object from file
        f = open(self.__filename__, 'r')
        data = []
        try:
            data = json.loads(f.read())
        except ValueError as err:
            pass
        f.close()
        return data

if __name__ == "__main__":
#    daemon = WSDaemon('/tmp/performance_report.pid', '/dev/null', '/tmp/performance_report.out', '/tmp/performance_report.err')
    daemon = WSDaemon('/tmp/performance_report.pid')
    if len(sys.argv) >= 2:
        if 'start' == sys.argv[1]: 
            del sys.argv[1:2]
            daemon.start()
        elif 'stop' == sys.argv[1]:
            daemon.stop()
        elif 'restart' == sys.argv[1]:
            del sys.argv[1:2]
            daemon.restart()
        else:
            print "Unknown command"
            sys.exit(2)
        sys.exit(0)
    else:
        print "usage: %s start|stop|restart" % sys.argv[0]
        sys.exit(2)
