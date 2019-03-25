#!/bin/bash
## Ambari Agent Install
ambari_version="2.6.2.0"
utilfqdn=`nslookup hw-utility-1 | grep Name | gawk '{print $2}'`
hostname=`hostname`

wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/${ambari_version}/ambari.repo -O /etc/yum.repos.d/ambari.repo
yum install ambari-agent -y
wget -nv http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.6.4.0/hdp.repo -O /etc/yum.repos.d/hdp.repo
wget -nv http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.22/repos/centos7/hdp-utils.repo -O /etc/yum.repos.d/hdp-utils.repo

# Modify /etc/ambari-agent/conf/ambari-agent.ini
sed -i "s/localhost/${utilfqdn}/g" /etc/ambari-agent/conf/ambari-agent.ini
service ambari-agent start


