#!/bin/bash
## Ambari Agent Install
ambari_version="2.6.1.0"
hdf_version="3.1.1.0"
utilfqdn=`nslookup hdf-utility-1 | grep Name | gawk '{print $2}'`

wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/${ambari_version}/ambari.repo -O /etc/yum.repos.d/ambari.repo
yum install ambari-agent -y
wget -nv http://public-repo-1.hortonworks.com/HDF/centos7/3.x/updates/${hdf_version}/hdf.repo -O /etc/yum.repos.d/hdf.repo

# Modify /etc/ambari-agent/conf/ambari-agent.ini
sed -i "s/localhost/${utilfqdn}/g" /etc/ambari-agent/conf/ambari-agent.ini
service ambari-agent start


