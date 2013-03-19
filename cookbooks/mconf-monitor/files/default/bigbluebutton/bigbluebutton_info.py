import sys, re
import bbb_api

# To store the parsed arguments
class InfoArgs:
    url = ""
    salt = ""

# To store the information fetched from a BBB server
class BigBlueButtonInfo:
    meetingCount = 0
    userCount = 0
    videoCount = 0
    audioCount = 0
    def addMeeting(self):
        self.meetingCount += 1
    def addToUsers(self, count):
        self.userCount += count
    def addToAudioUsers(self, count):
        self.audioCount += count
    def addToVideoUsers(self, count):
        self.videoCount += count
    def limits(self):
        return [self.meetingCount, self.userCount, self.audioCount, self.videoCount]

# Creates a InfoArgs object with the complete BBB url and salt
def info_args(host, port, salt):
    args = InfoArgs()
    args.salt = salt
    args.url = host
    if port != None:
        args.url += ":" + str(port)

    if not re.match("http[s]?://", args.url, re.IGNORECASE):
        args.url = "http://" + args.url
    if not args.url[len(args.url)-1] == '/':
        args.url += "/"
    args.url += "bigbluebutton/"

    return args

# Fetch information from a BBB server
def fetch(host, port, salt):
    args = info_args(host, port, salt)
    result = BigBlueButtonInfo()

    meetings = bbb_api.getMeetings(args.url, args.salt)

    # just in case there are no meetings in the server
    if "meetings" in meetings and meetings["meetings"] != None:
        for name, meeting in meetings["meetings"].iteritems():

            # only if the meeting is running
            if re.match("true", meeting["running"], re.IGNORECASE):
                result.addMeeting()
                if "participantCount" in meeting:
                    result.addToUsers(int(meeting["participantCount"]))
                if "listenerCount" in meeting:
                    result.addToAudioUsers(int(meeting["listenerCount"]))
                if "videoCount" in meeting:
                    result.addToVideoUsers(int(meeting["videoCount"]))

    return result
