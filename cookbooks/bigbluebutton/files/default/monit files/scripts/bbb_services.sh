#!/bin/bash
	PORT=""
	LOG_MESSAGE=""

	PORT=$1

	case $PORT in

		#check if PORT is a red5 port
		"5080")
                        NOW=$(date)
                        bbb-conf --restart
                        #if [ $? -eq 0 ]; then
                                 LOG_MESSAGE="[$NOW] Red5 HTTP port 5080 failed: BBB restarted"
                        #else
                                 #LOG_MESSAGE="[$NOW] Red5 HTTP port 5080 failed: BBB restart FAILED"
                        #fi
		;;
		"1935")
                        NOW=$(date)
                        bbb-conf --restart
                        #if [ $? -eq 0 ]; then
                                 LOG_MESSAGE="[$NOW] Red5 RTMP port 1935 failed: BBB restarted"
                        #else
                                 #LOG_MESSAGE="[$NOW] Red5 RTMP port 1935 failed: BBB restart FAILED"
                        #fi
		;;
		"9123")
                        NOW=$(date)
                        bbb-conf --restart
                        #if [ $? -eq 0 ]; then
                                 LOG_MESSAGE="[$NOW] Red5 Deskshare TCP port 9123 failed: BBB restarted"
                        #else
                                 #LOG_MESSAGE="[$NOW] Red5 Deskshare TCP port 9123 failed: BBB restart FAILED"
                        #fi
		;;

		#or is the Tomcat port
		"8080")
                        NOW=$(date)
                        bbb-conf --restart
                        #if [ $? -eq 0 ]; then
                                 LOG_MESSAGE="[$NOW] Tomcat HTTP port 8080 failed: BBB restarted"
                        #else
                                 #LOG_MESSAGE="[$NOW] Tomcat HTTP port 8080 failed: BBB restart FAILED"
                        #fi
		;;


		#or is the Nginx port
		"80")
			NOW=$(date)
			/etc/init.d/nginx restart
			#if [ $? -eq 0 ]; then
   				 LOG_MESSAGE="[$NOW] Nginx HTTP port 80 failed: restarted"
			#else
   				 #LOG_MESSAGE="[$NOW] Nginx HTTP port 80 failed: restart FAILED"
			#fi
		;;

		#or is the Redis port
		"6379")
                        NOW=$(date)
                        /etc/init.d/redis-server-2.2.4 restart
                        #if [ $? -eq 0 ]; then
                                 LOG_MESSAGE="[$NOW] Redis TCP port 6379 failed: restarted"
                        #else
                                 #LOG_MESSAGE="[$NOW] Redis TCP port 6379 failed: restart FAILED"
                        #fi
		;;


		#or is the Openoffice port
		"8100")
                        NOW=$(date)
                        /etc/init.d/bbb-openoffice-headless stop
			/etc/init.d/bbb-openoffice-headless start
                        #if [ $? -eq 0 ]; then
                                 LOG_MESSAGE="[$NOW] Openoffice TCP port 8100 failed: restarted"
                        #else
                                 #LOG_MESSAGE="[$NOW] Openoffice TCP port 8100 failed: restart FAILED"
                        #fi
		;;

                #or is a FreeSwitch port
                "8021")
                        NOW=$(date)
                        bbb-conf --restart
			#if [ $? -eq 0 ]; then
                       		LOG_MESSAGE="[$NOW] FreeSwitch TCP port 8021 failed: BBB restarted"
			#else
				#LOG_MESSAGE="[$NOW] FreeSwitch TCP port 8021 failed: BBB restart FAILED"
			#fi
                ;;
                "5060")
                        NOW=$(date)
                        bbb-conf --restart
			#if [ $? -eq 0 ]; then
                       		LOG_MESSAGE="[$NOW] FreeSwitch SIP port 5060 failed: BBB restarted"
                        #else
                                #LOG_MESSAGE="[$NOW] FreeSwitch SIP port 5060 failed: BBB restart FAILED"
                        #fi

                ;;


		#unknown port
		*)
			LOG_MESSAGE="Port not found: doing nothing"
		;;

	esac

	echo $LOG_MESSAGE >> /etc/monit/conf.d/scripts/logs/bbb_log_monit
