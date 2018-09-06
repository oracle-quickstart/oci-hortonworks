#!/bin/bash

## Modify resolv.conf to ensure DNS lookups work
sudo rm -f /etc/resolv.conf
sudo echo "search public1.hwvcn.oraclevcn.com public2.hwvcn.oraclevcn.com public3.hwvcn.oraclevcn.com private1.hwvcn.oraclevcn.com private2.hwvcn.oraclevcn.com private3.hwvcn.oraclevcn.com bastion1.hwvcn.oraclevcn.com bastion2.hwvcn.oraclevcn.com bastion3.hwvcn.oraclevcn.com" > /etc/resolv.conf
sudo echo "nameserver 169.254.169.254" >> /etc/resolv.conf

sudo yum install -y screen.x86_64
## Execute screen sessions in parallel
sleep .001
sudo screen -dmLS iscsi
sleep .001
sudo screen -dmLS tune
sleep .001
sudo screen -dmLS disk
sleep .001
sudo screen -dmLS ambari
sleep .001
sudo screen -XS iscsi stuff logfile /home/opc/`date +%Y%m%d`.1.log
sleep .001
sudo screen -XS iscsi stuff login on
sleep .001
sudo screen -XS iscsi stuff log on
sleep .001
sudo screen -XS iscsi stuff logfile flush 1
sleep .001
sudo screen -XS tune stuff logfile /home/opc/`date +%Y%m%d`.2.log
sleep .001
sudo screen -XS tune stuff login on
sleep .001
sudo screen -XS tune stuff log on
sleep .001
sudo screen -XS tune stuff logfile flush 1
sleep .001
sudo screen -XS disk stuff logfile /home/opc/`date +%Y%m%d`.3.log
sleep .001
sudo screen -XS disk stuff login on
sleep .001
sudo screen -XS disk stuff log on
sleep .001
sudo screen -XS disk stuff logfile flush 1
sleep .001
sudo screen -XS ambari stuff logfile /home/opc/`date +%Y%m%d`.3.log
sleep .001
sudo screen -XS ambari stuff login on
sleep .001
sudo screen -XS ambari stuff log on
sleep .001
sudo screen -XS ambari stuff logfile flush 1
sleep .001
## ISCSI device setup
sudo screen -S iscsi -X stuff '/home/opc/iscsi.sh\n'
sleep .001
## OS Tuning parameters
sudo screen -S tune -X stuff '/home/opc/tune.sh\n'
sleep .001
## Disk Formatting for all but /dev/sda 
sudo screen -S disk -X stuff '/home/opc/disk_setup.sh\n'
sleep .001
sudo screen -S ambari -X stuff '/home/opc/ambari_agent.sh\n'
