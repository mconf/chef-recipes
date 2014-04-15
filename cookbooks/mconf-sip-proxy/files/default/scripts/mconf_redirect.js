include("PhoneFormat.js");
include("bigbluebutton-api.js");
include("sha1.js");
include("mconf_redirect_conf.js");

var called_number = argv[0]; // the called number as typed
var source_addr = argv[1];

console_log("INFO", "[MCONF-SIP-PROXY] IP " + source_addr + " dialing to " + called_number);

var bbbapi = new BigBlueButtonApi(server_url, server_salt);
var req = bbbapi.urlFor("getMeetings", {});
var response = fetchUrl(req); // api call

response = response.replace(/\n/g, ""); // new XML() doesn't work with strings containing \n

var response = new XML(response);
var meetxml = response.meetings;

var meeting_available=false;

for each (meeting in meetxml.meeting) {
	var match = false;
	if (formatE164(default_int_code, called_number) == formatE164(default_int_code, meeting.dialNumber)) {
		console_log("INFO", "[MCONF-SIP-PROXY] Match by dialNumber"); match = true;
	} else if (called_number == meeting.voiceBridge) {
		console_log("INFO", "[MCONF-SIP-PROXY] Match by voiceBridge"); match = true;
	} else if (called_number == meeting.meetingName) {
		console_log("INFO", "[MCONF-SIP-PROXY] Match by meetingName"); match = true;
	}

	if (match) {
		var server_address = meeting.server;

		var params = {
			meetingId: meeting.meetingID,
			name: meeting.meetingName,
			role:"attendee",
			userIP: source_addr,
			type:"SIP",
			server: server_address
		};
		console_log("INFO", "[MCONF-SIP-PROXY] " + params);
		req = bbbapi.urlFor("addUserEvent", params, false);
		response = fetchUrl(req);
		console_log("INFO", "[MCONF-SIP-PROXY] " + response);

		var dest_uri = meeting.voiceBridge + "@" + server_address;
		if (mode == "redirect") {
			console_log("INFO", "[MCONF-SIP-PROXY] Redirecting call to " + dest_uri);
			session.execute("redirect", "sip:" + dest_uri);
		} else {
			console_log("INFO", "[MCONF-SIP-PROXY] Bridging call to " + dest_uri);
			session.execute("bridge", "sofia/external/" + dest_uri);
		}


/* CODE TO USE PIN PROTECTION, TEMPORARILY DISABLED
			var attempts = 3;
			var cnt=0;
			console_log("info","Starting PIN Collection\n");
			session.answer();
			var passOk=false;
			while (cnt<attempts) {
				session.flushDigits();
				pin = session.getDigits(4,"",10000);
				console_log("info","Collected PIN: " + pin + "\n");
				if (pin == meeting.pass) {
					passOk=true;
					console_log("INFO", meeting.voiceBridge + "\n");
					session.execute("bridge", "sofia/external/"+meeting.voiceBridge+"@"+server_address);
				} else {
					session.execute("playback", "/usr/local/freeswitch/sounds/<wav file here>");
				}
				cnt++;
			}
			if (!passOk) {
				session.execute("playback", "/usr/local/freeswitch/sounds/<wav file here>");
			}
*/
		meeting_available = true;
		break;
	}
}

if (!meeting_available) {
	session.execute("respond", "404");
	//inform the caller that the call was not successful
	//without the sicence stream, the wav file will not be heard with quality by the caller
	//session.execute("playback", "silence_stream://1000");
	//freeswitch default installation includes english wav files only
	// session.execute("playback", "/usr/local/freeswitch/sounds/<wav file here>"); /*uncomment here and include an audio file to play to the caller*/
	//session.execute("playback", "silence_stream://500");
	console_log("INFO", "[MCONF-SIP-PROXY] Meeting unavailable");
}
