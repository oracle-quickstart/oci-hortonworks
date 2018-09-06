#!/bin/bash
#### Bastion Master Setup Script

ssh_check () {
	ssh_chk="1"
	failsafe="1"
	if [ -z $user ]; then
		user="opc"
	fi
	echo -ne "Checking SSH as $user on ${hostfqdn} [*"
        while [ "$ssh_chk" != "0" ]; do
		ssh_chk=`ssh -o StrictHostKeyChecking=no -q -i /home/opc/.ssh/id_rsa ${user}@${hostfqdn} 'cat /home/opc/.done'`
                if [ -z $ssh_chk ]; then
                        sleep 5
                        echo -n "*"
                        continue
                elif [ $ssh_chk = "0" ]; then
                        if [ $failsafe = "1" ]; then
                                failsafe="0"
                                ssh_check="1"
                                sleep 10
                                echo -n "*"
                                continue
                        else
                                continue
                        fi
                else
                        sleep 5
                        echo -n "*"
                        continue
                fi
        done;
	echo -ne "*] - DONE\n"
        unset sshchk 
	unset user
}

host_discovery () {
## If Domain is modified in VCN config, this needs to be changed
domain=".hwvcn.oraclevcn.com"
endcheck=1
i=1
while [ $endcheck != 0 ]; do
        check=0
        for d in `seq 1 3`; do
                hname=`nslookup hw-utility-${i}.public${d}${domain} | grep Name`
                seqchk=`echo -e $?`
                if [ $seqchk = "0" ]; then
                        echo $hname | gawk '{print $2}'
                        check="1"
                fi
        done;
        if [ $check = "0" ]; then
                endcheck=0
        else
                endcheck=1
                i=$((i+1))
        fi
done

## MASTER NODE DISCOVERY
endcheck=1
i=1
while [ $endcheck != 0 ]; do
        check=0
        for d in `seq 1 3`; do
                hname=`nslookup hw-master-${i}.private${d}${domain} | grep Name`
                seqchk=`echo -e $?`
                if [ $seqchk = "0" ]; then
                        echo $hname | gawk '{print $2}'
                        check="1"
                fi
        done;
        if [ $check = "0" ]; then
                endcheck=0
        else
                endcheck=1
                i=$((i+1))
        fi
done

## WORKER NODE DISCOVERY
endcheck=1
i=1
while [ $endcheck != 0 ]; do
        check=0
        for d in `seq 1 3`; do
                hname=`nslookup hw-worker-${i}.private${d}${domain} | grep Name`
                seqchk=`echo -e $?`
                if [ $seqchk = "0" ]; then
                        echo $hname | gawk '{print $2}'
                        check="1"
                fi
        done;
        if [ $check = "0" ]; then
                endcheck=0
        else
                endcheck=1
                i=$((i+1))
        fi
done
}

### Firewall Configuration
## Set this flag to 1 to enable host firewalls, 0 to disable
firewall_on="0"
### Main execution below this point - all tasks are initiated from Bastion host inside screen session called from remote-exec ##
cd /home/opc/

## Set DNS to resolve all subnet domains
sudo rm -f /etc/resolv.conf
sudo echo "search public1.hwvcn.oraclevcn.com public2.hwvcn.oraclevcn.com public3.hwvcn.oraclevcn.com private1.hwvcn.oraclevcn.com private2.hwvcn.oraclevcn.com private3.hwvcn.oraclevcn.com bastion1.hwvcn.oraclevcn.com bastion2.hwvcn.oraclevcn.com bastion3.hwvcn.oraclevcn.com" > /etc/resolv.conf
sudo echo "nameserver 169.254.169.254" >> /etc/resolv.conf

## Cleanup any exiting files just in case
if [ -f host_list ]; then 
	rm -f host_list;
	rm -f hosts;
fi

## Continue with Main Setup 
# First do some network & host discovery
host_discovery >> host_list
utilfqdn=`cat host_list | grep hw-utility-1`
w1fqdn=`cat host_list | grep hw-worker-1`
for host in `cat host_list`; do 
	h_ip=`dig +short $host`
	echo -e "$h_ip\t$host" >> hosts
done;

master_ip=`dig +short ${utilfqdn}`

## Primary host setup section
for host in `cat host_list | gawk -F '.' '{print $1}'`; do
	hostfqdn=`cat host_list | grep $host`
        echo -e "\tConfiguring $host for deployment."
        host_ip=`cat hosts | grep $host | gawk '{print $1}'`
        ssh_check
	echo -e "Copying Setup Scripts...\n"
        ## Copy Setup scripts
        scp -o BatchMode=yes -o StrictHostkeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/hosts opc@$hostfqdn:~/
        scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/iscsi.sh opc@$hostfqdn:~/
        scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/node_prep.sh opc@$hostfqdn:~/
        scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/tune.sh opc@$hostfqdn:~/
        scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/disk_setup.sh opc@$hostfqdn:~/
	scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/ambari_agent.sh opc@$hostfqdn:~/
        ## Set Execute Flag on scripts
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn 'chmod +x *.sh'
        ## Execute Node Prep
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn 'sudo ./node_prep.sh &'
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn "sudo systemctl stop firewalld"
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn "sudo systemctl disable firewalld"
        ## Master Setup Files get copied here
        if [ $host = "hw-utility-1" ]; then
                echo -e "\tCopying Master Setup Files..."
                scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/startup.sh opc@$hostfqdn:~/
                scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/ambari_setup.sh opc@$hostfqdn:~/
                scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/.ssh/id_rsa opc@$hostfqdn:~/.ssh/
                ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn "chmod 0600 .ssh/id_rsa"
	fi
        echo -e "\tDone initializing $host.\n\n"
done;
## End Worker Node Setup
## Discovery for later configuration - look at resources on first worker
echo -e "Checking Resources on Worker Node..."
wprocs=`ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@${w1fqdn} 'cat /proc/cpuinfo | grep processor | wc -l'`
echo -e "$wprocs processors detected.."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@${w1fqdn} "free -hg | grep Mem" > /tmp/meminfo
memtotal=`cat /tmp/meminfo | gawk '{print $2}' | cut -d 'G' -f 1`
echo -e "${memtotal}GB of RAM detected..."
hdfsdisks=`ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@${w1fqdn} "cat /proc/partitions | grep -iv sda | sed 1,2d | wc -l"`
echo -e "${hdfsdisks} detected for HDFS use..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@${utilfqdn} "echo $hdfsdisks > /tmp/hdfsdisks"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@${utilfqdn} "echo $wprocs > /tmp/wprocs"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@${utilfqdn} "echo $memtotal > /tmp/memtotal"
## Install Ambari Agent
echo -e "Installing Ambari Agent..."
./ambari_agent.sh
## Finish Cluster Setup Below
echo -e "Pre-Install Bootstrapping Complete..."
hostfqdn="$utilfqdn"
user="root"
ssh_check
echo -e "\n"
echo -e "Running Ambari Server Setup..."
## Invoke CMS installer
install_success="1"
while [ $install_success = "1" ]; do
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@${utilfqdn} "sudo /home/opc/ambari_setup.sh"
	install_success=`echo -e $?`
	sleep 10
done
echo -e "Ambari Setup Complete."
#echo -e "Copying (if exists) HDFS Data Tiering file from first Worker."
#scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa root@hw-worker-1:/home/opc/hdfs_data_tiering.txt .
#if [ -f "hdfs_data_tiering.txt" ]; then 
#	echo -e "HDFS Data Tiering file found!  Copying to Utility node."
#	scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa hdfs_data_tiering.txt root@hw-utility-1:/home/opc/hdfs_data_tiering.txt
#fi
#echo -e "Starting Hortonworks..."
## Invoke SCM bootstrapping and initialization 
#ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@${utilfqdn} "sudo /home/opc/startup.sh"
echo -e "--------------------------------------------------------------------"
echo -e "---------------------CLUSTER SETUP COMPLETE-------------------------"
echo -e "--------------------------------------------------------------------"
