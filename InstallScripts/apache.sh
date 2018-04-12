#!/usr/bin/env bash

echo '>> Installing Apache and mysql client'

yum -y remove mariadb-libs
yum localinstall -y http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
yum -y install postfix
yum install -y mysql-community-devel mysql-community-client

yum install -y httpd httpd-devel mod_ssl openssh mod_rewrite mod_proxy mod_proxy_apj

systemctl start httpd.service
systemctl enable httpd.service

a2enmod rewrite proxy proxy_ajp

opencms_conf=/etc/httpd/conf.d/opencms.conf

rm -rf $opencms_conf # remove any previously created file

TOMCAT_SERV_IPADDR=192.168.33.11

cat >> $opencms_conf << EOF
ProxyRequests Off
<Proxy *>
        Order deny,allow
        Deny from none
        Allow from localhost
</Proxy>
ProxyPass 		/ ajp://$TOMCAT_SERV_IPADDR:8009/ retry=0
ProxyPassReverse 	/ ajp://$TOMCAT_SERV_IPADDR:8009/ retry=0
EOF

systemctl start httpd
systemctl enable httpd
systemctl list-unit-files -t service | grep httpd

echo ""
echo "Finished with Apache setup!"
echo ""

