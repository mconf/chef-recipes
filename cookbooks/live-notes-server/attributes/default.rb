#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

default[:mconf][:tools][:dir] = "/var/mconf/tools"
default[:notes][:xsbt][:version] = "0.11.2"
default[:notes][:xsbt][:dir] = "#{node[:mconf][:tools][:dir]}/xsbt"
default[:notes][:notes_server][:name] = "live-notes-server"
default[:notes][:notes_server][:dir] = "#{node[:mconf][:tools][:dir]}/#{node[:notes][:notes_server][:name]}"
default[:notes][:notes_server][:port] = "8095"
default[:notes][:sbt_launch][:url] = "http://typesafe.artifactoryonline.com/typesafe/ivy-releases/org.scala-tools.sbt/sbt-launch/#{node[:notes][:xsbt][:version]}/sbt-launch.jar"

