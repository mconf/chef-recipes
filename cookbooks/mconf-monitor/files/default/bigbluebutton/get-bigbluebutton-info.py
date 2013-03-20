#!/usr/bin/python

# TODO: set a different status when the response has a failure code
# TODO: method to verify the format of HOST

import sys
import bigbluebutton_info
import argparse
from urlparse import urlparse

# Exit statuses recognized by Nagios
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3

# Parse the limits given by the user into an array
def info_limits(string):
    limits = [ [0,0,0,0], [0,0,0,0] ] # defaults
    user_limits = string.split(":")
    if len(user_limits) != 2:
        msg = "%r is not a valid limit range" % string
        sys.stdout.write(msg)
        raise argparse.ArgumentTypeError(msg)

    for i, val in enumerate(user_limits):
        values = val.split(",")
        if len(values) != 4:
            msg = "%r is not a valid limit range" % val
            sys.stdout.write(msg)
            raise argparse.ArgumentTypeError(msg)
        limits[i] = values

    return limits

def parse_args():
    parser = argparse.ArgumentParser(description = "Fetches information from a BigBlueButton server")
    parser.add_argument("--host",
        required = True,
        help = "the BigBlueButton full HOST address. Format: http://192.168.0.101:8080/bigbluebutton",
        dest = "host",
        metavar = "<HOST>")
    parser.add_argument("--salt",
        required = True,
        help = "the SALT of your BigBlueButton server",
        dest = "salt",
        metavar = "<salt>")
    parser.add_argument("--limits",
        type = info_limits,
        default = "0,0,0,0:0,0,0,0",
        help = "the LIMITS for the service to enter CRITICAL and WARNING status. Format: \"meetings,users,audios,videos:meetings,users,audios,videos\", the first set for the CRITICAL status and the second for the WARNING",
        dest = "limits",
        metavar = "<limits>")
    return parser.parse_args()

# Check the service status using the limits informed by the user and the results from BBB
# Ex: get_status([2,3,2,1], [[0,0,30,30],[0,25,10,10]])
def get_status(results, limits):
    for status, limit_set in enumerate(limits):
        for i, limit in enumerate(limit_set):
            limit = int(limit)
            if limit > 0:                # 0 means disabled
                if results[i] >= limit:  # if the result is over the limit
                    return 2-status      # 1:WARNING, 2:CRITICAL
    return OK

# Returns the output message and performance data
# 'limits' is in the format [[0,0,30,30],[0,25,10,10]]
def get_output_message(results, limits):
    # removes the zeros from the limits list because zero disables the limit in this implementation
    limits = [[limit if limit != "0" else "" for limit in limit_list] for limit_list in limits]

    msg =  "Meetings: " + str(results.meetingCount)
    msg += ", Users: " + str(results.userCount)
    msg += ", User with audio: " + str(results.audioCount)
    msg += ", User with video: " + str(results.videoCount)
    perf  = "meetings=" + str(results.meetingCount) + ";" + limits[0][0] + ";" + limits[1][0] + ";0; "
    perf += "users=" + str(results.userCount) + ";" + limits[0][1] + ";" + limits[1][1] + ";0; "
    perf += "audios=" + str(results.audioCount) + ";" + limits[0][2] + ";" + limits[1][2] + ";0; "
    perf += "videos=" + str(results.videoCount) + ";" + limits[0][3] + ";" + limits[1][3] + ";0; "
    return msg + "|" + perf

def main():
    """
    Fetches the following information from a BigBlueButton server:
    - Number of meetings
    - Number of users connected (in all meetings)
    - Number of users with video (in all meetings)
    - Number of users with audio (in all meetings)
    Returns the codes:
    0: all ok
    1: entered the WARNING status
    2: entered the CRITICAL status
    1: couldn't get an anwser from BBB, is at the UNKNOWN status
    """

    # args
    args = parse_args()

    # get the data from BBB
    try:
        url = urlparse(args.host)
        results = bigbluebutton_info.fetch(url.hostname, url.port, args.salt)
    except Exception as e:
        sys.stdout.write(str(e))
        sys.exit((UNKNOWN))

    # output
    sys.stdout.write(get_output_message(results, args.limits))
    sys.exit((get_status(results.limits(), args.limits)))

if __name__ == '__main__':
    main()
