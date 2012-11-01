default[:mconf][:tools][:path] = "/var/mconf/tools"
default[:mconf][:log][:path] = "/var/mconf/log"
default[:notes][:xsbt][:version] = "0.11.2"
default[:notes][:xsbt][:path] = "#{node[:mconf][:tools][:path]}/xsbt"
default[:notes][:notes_server][:name] = "live-notes-server"
default[:notes][:notes_server][:path] = "#{node[:mconf][:tools][:path]}/#{node[:notes][:notes_server][:name]}"
default[:notes][:notes_server][:port] = "8095"
default[:notes][:sbt_launch][:url] = "http://typesafe.artifactoryonline.com/typesafe/ivy-releases/org.scala-tools.sbt/sbt-launch/#{node[:notes][:xsbt][:version]}/sbt-launch.jar"

