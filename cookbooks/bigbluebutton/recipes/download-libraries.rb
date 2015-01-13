repo = "http://fpdownload.adobe.com/pub/swz"

[ "flex/4.5.0.20967/mx_4.5.0.20967.swz",
  "flex/4.5.0.20967/rpc_4.5.0.20967.swz",
  "tlf/2.0.0.232/textLayout_2.0.0.232.swz",
  "flex/4.5.0.20967/framework_4.5.0.20967.swz" ].each do |lib|
    [ "/var/www/bigbluebutton/client/locale",
      "/var/www/bigbluebutton/client/branding/css" ].each do |dst|
        directory dst do
          recursive true
          action :create
        end
        remote_file "#{dst}/#{File.basename lib}" do
            source "#{repo}/#{lib}"
        end
    end
end
