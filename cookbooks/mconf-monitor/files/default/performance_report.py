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
import json
import signal
import sys

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
#                if printProcStatus:
#                    print "sorted by memory usage"
#                    for i, p in zip(range(5),processesSortByMem):
#                        print (" process name: " + str(p.name) + " mem use: " + str(p.get_memory_percent()))
#                    print "\n"
#                    print "sorted by processor usage"
#                    for i, p in zip(range(5),processesSortByProc):
#                        print (" process name: " + str(p.name) + " proc use: " + str(p.get_cpu_percent(interval=0)))
#                    print "\n\n\n\n\n\n\n\n"
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
        print "%s\t%s\t%s\t%s\t" % (self.config.hostname, service, str(state), message)
        sys.stdout.flush()

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

class MountedDisksReporterHelper(Reporter):
    def __init__(self, config, path):
        Reporter.__init__(self, config)
        self.service = "Disk Report"
        self.mountedDiskPath = path
        self.maximum, self.unit = self.findBestUnit(float(psutil.disk_usage(self.mountedDiskPath).total))
        self.warning = (self.config.disk_warning * self.maximum) / 100
        self.critical = (self.config.disk_critical * self.maximum) / 100

    def findBestUnit(self, value):
        if value >= 1024 * 1024 * 1024 * 1024:
            return value / (1024 * 1024 * 1024 * 1024), "TB"
        if value >= 1024 * 1024 * 1024:
            return value / (1024 * 1024 * 1024), "GB"
        if value >= 1024 * 1024:
            return value / (1024 * 1024), "MB"
        if value >= 1024:
            return value / (1024), "KB"
        return value, "B"

    def data(self): 
        currentUsage = (psutil.disk_usage(self.mountedDiskPath).percent * self.maximum) / 100
        state = self.checkStatus(currentUsage)

        humamMessage = "%s: %d%s of %d%s (%d%%)" % (self.mountedDiskPath, currentUsage, self.unit, self.maximum, self.unit, (currentUsage * 100) / self.maximum) \

        nagiosMessage = self.formatMessage(currentUsage, self.mountedDiskPath, self.unit)
        return humamMessage, nagiosMessage, state

    def formatMessage(self, usage, label, unit):
        format = "%s%%s=%%.2f%s;%d;%d;%d;%d" % (label, unit.replace("%", "%%"), self.warning, self.critical, self.minimum, self.maximum)
        return format % ("", usage)

class MountedDisksReporter(Reporter):
    def __init__(self, config): 
        Reporter.__init__(self, config)
        self.service = "Mounted Disks Report"

        self.mountedDiskReporters = []

        # get all VALID mounted disks
        for partition in psutil.disk_partitions(all=False):
            if psutil.disk_usage(partition.mountpoint).total > 0:
                self.mountedDiskReporters.append(MountedDisksReporterHelper(config, partition.mountpoint))

    def data(self):
        humamMessages = []
        nagiosMessages = []
        diskStates = []
        
        for diskReporter in self.mountedDiskReporters:
            humamMessage, nagiosMessage, state = diskReporter.data()
            humamMessages.append(humamMessage)
            nagiosMessages.append(nagiosMessage)
            diskStates.append(state)

        message = self.formatMessage(humamMessages, nagiosMessages)
        return message,max(diskStates)

    def formatMessage(self,humamMessages, nagiosMessages):
        concatenatedHumamMessages = string.join(humamMessages, ', ')
        concatenatedNagiosMessages = string.join(nagiosMessages,' ')
        return concatenatedHumamMessages + "| " + concatenatedNagiosMessages

    def kill(self):
        self.terminate = True

    def threadLoop(self):
        time.sleep(1)

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
        self.numberOfCores = psutil.NUM_CPUS
        
    def threadLoop(self):
        self.list.append(psutil.cpu_percent(1, percpu=False))
    
    def data(self):
        list_avg = self.list.avg()
        # message mount
        message = "CPU usage: %.1f%% Model: %s (%s cores) " % (list_avg, self.processor, self.numberOfCores) \
            + "|" + self.formatMessage(self.list, "cpu", "%") + "cores=" + str(self.numberOfCores) + ";;;;"
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
#            print "Couldn't find the network interface %s" % (self.config.network_interface)
            self.config.network_interface = None
            for i in pnic_before.keys():
                if i != "lo":
                    self.config.network_interface = i
                    break
            if self.config.network_interface == None:
                return
#            print "Using %s instead" % (self.config.network_interface)
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
        sent_avg = self.sent.avg()
        recv_avg = self.recv.avg()
        # state mount
        state = max(int(self.checkStatus(sent_avg)), int(self.checkStatus(recv_avg)))
        sent_avg, sent_unit = self.normalize(sent_avg)
        recv_avg, recv_unit = self.normalize(recv_avg)
        # message mount
        message = "Network bandwidth used: up %.1f%s - down %.1f%s" \
            % (sent_avg, sent_unit, recv_avg, recv_unit) + " |" \
            + self.formatMessage(self.sent, "sent", "") \
            + self.formatMessage(self.recv, "recv", "")
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
        default = "2",
        metavar = "<send_rate>")
    parser.add_argument("--network-warning", required=False, default="40000",
        help="define the warning limit in kbps", dest="network_warning", 
        metavar="<network_warning>")
    parser.add_argument("--network-critical", required=False, default="70000", 
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
        self.network_interface = args.network_interface
        self.hostname = args.hostname
        self.send_rate = int(args.send_rate)
        self.network_warning = int(args.network_warning)
        self.network_critical = int(args.network_critical)
        self.cpu_warning = int(args.cpu_warning)
        self.cpu_critical = int(args.cpu_critical)
        self.memory_warning = int(args.memory_warning)
        self.memory_critical = int(args.memory_critical)
        self.disk_warning = int(args.disk_warning)
        self.disk_critical = int(args.disk_critical)

# http://stackoverflow.com/questions/1112343/how-do-i-capture-sigint-in-python
def signal_handler(signal, frame):
    print '\nYou pressed Ctrl+C!'
    sender.kill()
    for reporterThread in threadsList:
        reporterThread.kill()
    sender.join()
    for reporterThread in threadsList:
        reporterThread.join()
    sys.exit(0)
        
if __name__ == '__main__':
    threadsList = []
    
    config = Configuration(parse_args())
    
    # here we should have the main call to the reporter threads
    threadsList.append(NetworkReporter(config))
    threadsList.append(ProcessorReporter(config))
    threadsList.append(MemoryReporter(config))
    threadsList.append(DiskReporter(config))
    threadsList.append(MountedDisksReporter(config))
    #processesAnalyzer thread
#    threadsList.append(processesAnalyzer(config))

    sender = Sender(config, threadsList)
    # start every thread
    for reporterThread in threadsList:
        reporterThread.start()
    sender.start()
    
    signal.signal(signal.SIGINT, signal_handler)
    print 'Press Ctrl+C'
    signal.pause()
    
