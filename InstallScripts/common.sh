#!/usr/bin/env bash
set -eu

# yum -y update kernel

# install for develop
yum install -y kernel-devel kernel-headers dkms
yum install -y mailx git sqlite-devel libmcrypt-devel openssl-devel gcc-c++ psmisc

yum update -y

# Let's make sure we have the latest version of bash installed, which
# are patched to protect againt the shellshock bug. Here is an article explaning
# how to check if your bash is vulnerable: http://security.stackexchange.com/questions/68168/is-there-a-short-command-to-test-if-my-server-is-secure-against-the-shellshock-b
yum update -y bash

isCentOs7=true

# Let's make sure that we have the EPEL and IUS repositories installed.
# This will allow us to use newer binaries than are found in the standard CentOS repositories.
# http://www.rackspace.com/knowledge_center/article/install-epel-and-additional-repositories-on-centos-and-red-hat
yum install -y epel-release
if [ "$isCentOs7" != true ]
then
    # The following is needed to get the epel repository to work correctly. Here is
    # a link with more information: http://stackoverflow.com/questions/26734777/yum-error-cannot-retrieve-metalink-for-repository-epel-please-verify-its-path
    sed -i "s/mirrorlist=https/mirrorlist=http/" /etc/yum.repos.d/epel.repo
fi

# Let's make sure that openssl is installed:
yum install -y openssl

# Let's make sure that curl is installed:
yum install -y curl
# Install useful tools and utilities that will help with debugging
# we're at it, let's also install 'awk'. It's most likely that these packages
# are already installed, but let's be sure. By the way, yes it is 'gawk' as the
# pacakge name:
yum install -y sed
yum install -y gawk
yum install -y vim
yum install -y telnet
yum install -y tcpdump
yum install -y traceroute
yum install -y net-tools unzip wget

# set up UTC timezone
timedatectl set-timezone UTC

# disable SElinux
cp -p /etc/selinux/config /etc/selinux/config.orig
sed -i -e "s|^SELINUX=.*|SELINUX=disabled|" /etc/selinux/config

# set up vagrant public key
curl https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub >> /home/vagrant/.ssh/authorized_keys


# set up ntpd
yum install -y ntp
systemctl enable ntpd
systemctl enable ntpdate
systemctl list-unit-files -t service | grep ntpd
