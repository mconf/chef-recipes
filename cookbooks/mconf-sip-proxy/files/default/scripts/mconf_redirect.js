include("PhoneFormat.js");
include("bigbluebutton-api.js");
include("mconf_redirect_conf.js");
use("CURL");
use("XML");

var called_number = argv[0]; // the called number as typed
var source_addr = argv[1];
var caller_name = argv[2];
var sip_user_agent = argv[3];

console_log("INFO", "[MCONF-SIP-PROXY] IP " + source_addr + " dialing to " + called_number + "\n");

var bbbapi = new BigBlueButtonApi(server_url, server_salt);
var curl = new CURL();

function getMeetingsCallback(string, arg) {
	console_log("info", string);
	var response = new XML(string);
	var return_code = response.getChild('returncode').data;
	if (return_code != "SUCCESS") {
        	console_log("ERROR", "[MCONF-SIP-PROXY] Failed to get meetings, return code " + return_code + "\n");
	} else {
		console_log("INFO", "[MCONF-SIP-PROXY] Meetings successfully fetched\n");
	}

	var child = response.getChild('meetings').getChild('meeting');
	var match;
	while (child) {
		match = matchMeeting(child);
		if (match) {
			registerEvent(child);
			redirectCall(child);
			break;
		}
		child = child.next();
	}

	if (!match) {
		session.execute("respond", "404");
		console_log("INFO", "[MCONF-SIP-PROXY] Meeting unavailable\n");
	}

	return true;
}

function matchMeeting(meeting) {
	var match = false;
	var dialNumber = getDialNumber(meeting);
	var voiceBridge = getVoiceBridge(meeting);
	var meetingName = getMeetingName(meeting);

        if (formatE164(default_int_code, called_number) == formatE164(default_int_code, dialNumber)) {
                console_log("INFO", "[MCONF-SIP-PROXY] Match by dialNumber\n"); match = true;
        } else if (called_number == voiceBridge) {
                console_log("INFO", "[MCONF-SIP-PROXY] Match by voiceBridge\n"); match = true;
        } else if (called_number == meetingName) {
                console_log("INFO", "[MCONF-SIP-PROXY] Match by meetingName\n"); match = true;
        }

	return match;
}

function getServerAddress(meeting) { return meeting.getChild('server').getChild('address').data; }
function getMeetingId(meeting) { return meeting.getChild('meetingID').data; }
function getMeetingName(meeting) { return meeting.getChild('meetingName').data; }
function getDialNumber(meeting) { return meeting.getChild('dialNumber').data; }
function getVoiceBridge(meeting) { return meeting.getChild('voiceBridge').data; }

function registerEvent(meeting) {
	var server_address = getServerAddress(meeting);
	console_log("INFO", "[MCONF-SIP-PROXY] Server address: " + server_address + "\n");
	if (server_address == "") {
		console_log("ERROR", "[MCONF-SIP-PROXY] Couldn't find a server to redirect the call\n");
		return;
	}

	var fs_version = apiExecute("version", "short").replace("\n", "");

	var sip_proxy_token = "";
	if (sip_proxy_version != "" || sip_proxy_commit != "") {
		sip_proxy_token = " MconfSipProxy/" + sip_proxy_version;
		if (sip_proxy_commit != "") {
			sip_proxy_token += "@" + sip_proxy_commit;
		}
	}

	var ua = sip_user_agent + sip_proxy_token + " FreeSWITCH/" + fs_version;

	var params = {
		meetingID: getMeetingId(meeting),
		name: caller_name,
		role: "attendee",
		userIP: source_addr,
		userAgent: ua
	};
	var req = bbbapi.urlFor("addUserEvent", params, false);
	console_log("INFO", "[MCONF-SIP-PROXY] Registering event: " + req + "\n");
	//curl.run("POST", req.split('?')[0], req.split('?')[1], registerEventCallback, null, null);
	// on BigBlueButton, all data must be passed by the URL
	curl.run("POST", req, "", registerEventCallback, null, null);
}

function registerEventCallback(string, arg) {
	console_log("INFO", "[MCONF-SIP-PROXY] " + string + "\n");
	return true;
}

function redirectCall(meeting) {
	var voice_bridge = getVoiceBridge(meeting);
	var server_address = getServerAddress(meeting);
	var dest_uri = voice_bridge + "@" + server_address;

	if (mode == "redirect") {
		console_log("INFO", "[MCONF-SIP-PROXY] Redirecting call to " + dest_uri + "\n");
		session.execute("redirect", "sip:" + dest_uri);
	} else {
		console_log("INFO", "[MCONF-SIP-PROXY] Bridging call to " + dest_uri + "\n");
		session.execute("bridge", "sofia/external/" + dest_uri);
	}
}

function getMeetings() {
	var req = bbbapi.urlFor("getMeetings", {});
	curl.run("GET", req.split('?')[0], req.split('?')[1], getMeetingsCallback, null, null);
}

getMeetings();

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
