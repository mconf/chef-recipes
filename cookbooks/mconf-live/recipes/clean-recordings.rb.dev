#
# Cookbook Name:: mconf-live
# Recipe:: clean-recordings
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

require 'nokogiri'
require 'open-uri'
require 'digest/sha1'

recordings_local = []
Dir["/var/bigbluebutton/published/mconf/**/metadata.xml"].each do |filename|
    doc = Nokogiri.XML(File.open(filename, 'rb'))
    obj = {
        meeting_id: doc.xpath("//meta/meetingId").first.text,
        record_id: doc.xpath("/recording/id").first.text
    }
    recordings_local << obj
end

meeting_ids = recordings_local.map{|r| r[:meeting_id]}.join(',')

recording_servers = [{
    bbb: {
        server_url: "http://143.54.10.137",
        salt: "e5ed8261bd673aeadede275df83b33b2"
    }
}, {
    bbb: {
        server_url: "http://143.54.10.119",
        salt: "ab82c41a0024bcadb54f4b1c19aabf89"
    }
}]

# recording_servers = search(:node, "role:mconf-recording-server AND chef_environment:#{node.chef_environment}")

get_recordings_urls = []
recording_servers.each do |recording_server|
    params = URI.escape("meetingID=#{meeting_ids}")
    checksum = Digest::SHA1.hexdigest "getRecordings#{params}#{recording_server[:bbb][:salt]}"
    url = "#{recording_server[:bbb][:server_url]}/bigbluebutton/api/getRecordings?#{params}&checksum=#{checksum}"
    get_recordings_urls << url
end

recordings_remote_match = []
get_recordings_urls.each do |get_recordings_url|
    doc = Nokogiri::XML(open(get_recordings_url))
    doc.xpath("//recording/recordID").each do |record_id|
        record_id = record_id.text
        if recordings_local.map{|r| r[:record_id]}.include? record_id
            recordings_remote_match << record_id
        end
    end
end

recordings_remote_match.each do |record_id|
    puts "I could safely remove #{record_id}"
end
(recordings_local.map{|r| r[:record_id]} - recordings_remote_match).each do |record_id|
    puts "Leaving unhandled #{record_id}"
end
