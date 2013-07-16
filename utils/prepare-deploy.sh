#!/bin/bash

set -e

BASE_DIR="/home/ubuntu"
TAR_NAME="deploy-`date +'%Y%m%d-%H%M%S'`.tar.gz"
DEPLOY_NAME="deploy"
DEPLOY_DIR="$BASE_DIR/$DEPLOY_NAME"
DEPLOY_CLIENT_DIR="$DEPLOY_DIR/client"
DEPLOY_APPS_DIR="$DEPLOY_DIR/apps"
DEPLOY_WEB_DIR="$DEPLOY_DIR/web"
DEPLOY_CONFIG_DIR="$DEPLOY_DIR/config"
DEPLOY_DEMO_DIR="$DEPLOY_DIR/demo"
DEPLOY_RECORD_AND_PLAYBACK_DIR="$DEPLOY_DIR/record-and-playback"

if [ -d $DEPLOY_DIR ]
then
    rm -r $DEPLOY_DIR
fi
echo "Creating deploy dir: $DEPLOY_DIR"
mkdir -p $DEPLOY_DIR

echo "+++++ Building bigbluebutton-client"
cd ~/dev/bigbluebutton/bigbluebutton-client/
ant clean && ant locales && ant
mkdir -p $DEPLOY_CLIENT_DIR
cp -r client/* $DEPLOY_CLIENT_DIR/

echo
echo "+++++ Building bigbluebutton-apps"
cd ~/dev/bigbluebutton/bigbluebutton-apps/
gradle clean resolveDeps build war deploy
mkdir -p $DEPLOY_APPS_DIR
cp -r build/bigbluebutton $DEPLOY_APPS_DIR

echo
echo "+++++ Building bbb-video"
cd ~/dev/bigbluebutton/bbb-video/
sudo rm -r /usr/share/red5/webapps/video/streams/
gradle clean resolveDeps build war deploy
sudo chown red5:adm -R /usr/share/red5/webapps/video/streams/
cp -r build/video $DEPLOY_APPS_DIR

echo
echo "+++++ Building bbb-voice"
cd ~/dev/bigbluebutton/bbb-voice/
gradle clean resolveDeps build war deploy
cp -r build/sip $DEPLOY_APPS_DIR

echo
echo "+++++ Building deskshare"
cd ~/dev/bigbluebutton/deskshare/
gradle clean resolveDeps build war deploy
cp -r app/build/deskshare $DEPLOY_APPS_DIR

echo
echo "+++++ Building bigbluebutton-web"
cd ~/dev/bigbluebutton/bigbluebutton-web/
cp /var/lib/tomcat6/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties grails-app/conf/
gradle clean resolveDeps && ant war
mkdir -p $DEPLOY_WEB_DIR
cp bigbluebutton-0.70dev.war $DEPLOY_WEB_DIR/bigbluebutton.war
# deploy
sudo cp bigbluebutton-0.70dev.war /var/lib/tomcat6/webapps/bigbluebutton.war

echo
echo "+++++ Copying bigbluebutton-config"
cd ~/dev/bigbluebutton/bigbluebutton-config/
mkdir -p $DEPLOY_CONFIG_DIR
cp bin/* $DEPLOY_CONFIG_DIR/

echo
echo "+++++ Building bbb-api-demo"
cd ~/dev/bigbluebutton/bbb-api-demo/
cp /var/lib/tomcat6/webapps/demo/bbb_api_conf.jsp src/main/webapp/
gradle clean resolveDeps build
mkdir -p $DEPLOY_DEMO_DIR
cp build/libs/demo.war $DEPLOY_DEMO_DIR/
# deploy
sudo cp build/libs/demo.war /var/lib/tomcat6/webapps/

echo
echo "+++++ Building record-and-playback"

cd ~/dev/bigbluebutton/record-and-playback/
mkdir -p $DEPLOY_RECORD_AND_PLAYBACK_DIR
cp -r * $DEPLOY_RECORD_AND_PLAYBACK_DIR/
# remove the test recordings
rm -r $DEPLOY_RECORD_AND_PLAYBACK_DIR/core/resources/raw
sudo ./deploy.sh

echo
echo "+++++ Generating $TAR_NAME"
cd $BASE_DIR/$DEPLOY_NAME
tar czf $TAR_NAME *

echo
echo "+++++ Done!"

