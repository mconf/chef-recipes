default[:freeswitch][:group] = "daemon"
default[:freeswitch][:install_method] = "source"
default[:freeswitch][:source][:origin] = "tar"
# these are the default enabled modules of freeswitch
default[:freeswitch][:source][:modules] = %w[
applications/mod_cluechoo
applications/mod_commands
applications/mod_conference
applications/mod_db
applications/mod_dptools
applications/mod_enum
applications/mod_esf
applications/mod_expr
applications/mod_fifo
applications/mod_fsv
applications/mod_hash
applications/mod_httapi
applications/mod_sms
applications/mod_spandsp
applications/mod_valet_parking
applications/mod_voicemail
codecs/mod_amr
codecs/mod_b64
codecs/mod_bv
codecs/mod_g723_1
codecs/mod_g729
codecs/mod_h26x
codecs/mod_speex
codecs/mod_vp8
dialplans/mod_dialplan_asterisk
dialplans/mod_dialplan_xml
endpoints/mod_loopback
endpoints/mod_skinny
endpoints/mod_sofia
event_handlers/mod_cdr_csv
event_handlers/mod_cdr_sqlite
event_handlers/mod_event_socket
formats/mod_local_stream
formats/mod_native_file
formats/mod_sndfile
formats/mod_tone_stream
languages/mod_lua
languages/mod_spidermonkey
loggers/mod_console
loggers/mod_logfile
loggers/mod_syslog
say/mod_say_en
xml_int/mod_xml_cdr
xml_int/mod_xml_rpc
xml_int/mod_xml_scgi
]

default[:freeswitch][:mconf_proxy][:fetch_url] = ""
default[:freeswitch][:mconf_proxy][:default_int_code] = "BR"