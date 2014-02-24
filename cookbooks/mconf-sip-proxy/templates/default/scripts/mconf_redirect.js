/*
in order to print something in the freeswitch console, "conlole_log" can be used in this script as follows:
console_log(level, message);
example:
console_log("INFO", "your message here");
*/
include("PhoneFormat.js");

var calledNumber = argv[0]; //the called number as typed
var sourceAddr = argv[1];

var fullNumber = formatE164("<%= @default_int_code %>", calledNumber);

console_log("INFO", "##### Número discado a partir de " + sourceAddr + " convertido para o formato E164(inclui o código do país):" + fullNumber + " #####\n");

var response = fetchUrl("<%= @fetch_url %>"); //the balancer server provides us information about the meetings
response = response.replace(/\n/g, ""); //'new XML()' doesn't work with strings containing '\n'

//console_log("INFO", response + "\n");

var response = new XML(response);

var meetxml = response.meetings;

var meetingAvailable=false;

for each (meeting in meetxml.meeting) {
	var match = (calledNumber == meeting.voiceBridge || fullNumber == formatE164("<%= @default_int_code %>", meeting.dialNumber) || calledNumber == meeting.meetingName);
	if (match) {
		var server_address = meeting.server;
		//console_log("info", typeof meeting +"\n");
		if (true) {// disabling PIN collection
			session.execute("redirect", "sip:" + meeting.voiceBridge + "@" + server_address);
			//session.execute("bridge", "sofia/external/70898@143.54.10.185");//+meeting.voiceBridge+"@"+server_address);
		} else {
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
		}
		meetingAvailable = true;
		break;
	}
}

if (!meetingAvailable) {
	session.execute("respond", "404");
	//inform the caller that the call was not successful
	//without the sicence stream, the wav file will not be heard with quality by the caller
	session.execute("playback", "silence_stream://1000");
	//freeswitch default installation includes english wav files only
	session.execute("playback", "/usr/local/freeswitch/sounds/<wav file here>"); /*uncomment here and include an audio file to play to the caller*/
	session.execute("playback", "silence_stream://500");
	console_log("INFO", "meeting unavailable\n");
}
