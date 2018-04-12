#!/usr/bin/env bash

echo '>> Install mysql client'

yum -y remove mariadb-libs
yum localinstall -y http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
yum -y install postfix
yum install -y mysql-community-devel mysql-community-client

echo '>> Install java'

yum install -y java-1.8.0-openjdk
yum install -y java-1.8.0-openjdk-devel

# create tomcat user and group
echo '>> Create tomcat user and group'
groupadd tomcat
useradd -M -s /bin/nologin -g tomcat -d /opt/tomcat tomcat

# download and install tomcat
echo '>>  Download and install tomcat'

CATALINA_HOME=/opt/tomcat
APACHE_TOMCAT_FILE=apache-tomcat-8.5.30.tar.gz
APACHE_TOMCAT_DOWNLOAD_PATH=http://mirror.reverse.net/pub/apache/tomcat/tomcat-8/v8.5.30/bin
(
  cd /opt;
  rm -f $APACHE_TOMCAT_FILE # remove any leftovers from previous runs
  rm -rf $CATALINA_HOME
  wget $APACHE_TOMCAT_DOWNLOAD_PATH/$APACHE_TOMCAT_FILE
  if [ $? != 0 ] then
    echo "wget apache-tomcat download failed. Check wget works"
    exit 1
  fi
  mkdir  $CATALINA_HOME
  tar xvf $APACHE_TOMCAT_FILE -C $CATALINA_HOME --strip-components=1;
  if [ $? != 0 ] then
    echo "tar extraction of $APACHE_TOMCAT_FILE failed. Check disk space"
    exit 1
  fi
)

# set appropriate file permission
echo '>> Set appropriate tomcat file permission'

(
  cd $CATALINA_HOME;
  #tomcat group ownership over the entire installation directory
  chgrp -R tomcat $CATALINA_HOME;

  # tomcat group read access to the conf directory and all of its contents, and execute access to the directory itself
  chmod -R g+r conf;
  chmod g+x conf;

  # make the tomcat user the owner of the webapps, work, temp, and logs directories
  chown -R tomcat webapps/ work/ temp/ logs/
)

# set up systemd startup file for tomcat
echo '>> Set up systemd startup file for tomcat'

tc_service=/etc/systemd/system/tomcat.service
systemctl stop tomcat
rm -f $tc_service # clean up any pervious remnants of this file
cat >> $tc_service <<EOF
# Systemd unit file for tomcat
[Unit]
Description=Apache Tomcat Web Application Container
After=syslog.target network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/jre
Environment=CATALINA_PID=$CATALINA_HOME/temp/tomcat.pid
Environment=CATALINA_HOME=$CATALINA_HOME
Environment=CATALINA_BASE=$CATALINA_HOME
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=$CATALINA_HOME/bin/startup.sh
ExecStop=/bin/kill -15 $MAINPID

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start tomcat
systemctl enable tomcat

systemctl list-unit-files -t service | grep tomcat

echo ""
echo "Finished with tomcat  setup!"
echo ""

echo ""
echo "Starting opemcms setup!"
echo ""

OPENCMS_FILE=opencms-10.5.3.zip
OPENCMS_DOWNLOAD_PATH=http://www.opencms.org/downloads/opencms

(
  cd /opt;
  rm -f $OPENCMS_FILE # remove any remnants of previous runs
  wget $OPENCMS_DOWNLOAD_PATH/$OPENCMS_FILE
  if [ $? != 0 ] then
    echo "wget opencms download failed. Check wget works"
    exit 1
  fi
  unzip $OPENCMS_FILE

  # deploy opencms.war as ROOT.war to make apache happy since we are running this in a three tier configuration: apache -> tomcat(opencms) -> mysql

  rm -rf $CATALINA_HOME/webapps/ROOT
  mv opencms.war $CATALINA_HOME/webapps/ROOT.war
  chown tomcat:tomcat $CATALINA_HOME/webapps/ROOT.war
)

# restart tomcat 
systemctl restart tomcat # this will deploy opencms

# Introducing a delay for tomcat deployment of opencms to finish
# Ideally, there should be a better mechanism - perhaps test the existence of setup file and wait till its
# created.
sleep 5

setup_file=$CATALINA_HOME/webapps/ROOT/WEB-INF/setup.sh
chmod a+x $setup_file
if [ $? != 0 ] then
  echo "chmod setup.sh failed. Might be a race: tomcat deployment of opemcms might not have completed"
  exit 1
fi

SERVER_IPADDR=192.168.33.11
MYSQL_IPADDR=192.168.33.12

# now configure opencms
opencms_config=/tmp/opencms.config
rm -f $opencms_config # clean up any pervious remnants of this file
cat >> $opencms_config << EOF
setup.webapp.path=$CATALINA_HOME/webapps/ROOT
setup.default.webapp=ROOT
setup.install.components=workplace,releasenotes,template3,devdemo,bootstrap

db.product=mysql
db.provider=mysql
db.create.user=opencmsuser
db.create.pwd=@0penCms413@
db.worker.user=opencmsuser
db.worker.pwd=@0penCms413@
db.connection.url=jdbc:mysql://$MYSQL_IPADDR:3306/
db.name=opencms_db
db.create.db=false
db.create.tables=true
db.dropDb=true
db.default.tablespace=
db.index.tablespace=
db.jdbc.driver=org.gjt.mm.mysql.Driver
db.template.db=
db.temporary.tablespace=

server.url=http://$SERVER_IPADDR:8080
server.name=OpenCmsServer
server.ethernet.address=
server.servlet.mapping=
EOF

$setup_file -path $opencms_config

systemctl restart tomcat
