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
## UTILITY NODE DISCOVERY
endcheck=1
while [ "$endcheck" = "1" ]; do
        for i in `seq 1 3`; do
                hname=`host hw-utility-${i}`
                hchk=$?
                if [ "$hchk" = "1" ]; then
                        endcheck="0"
                else
                        echo "$hname" | head -n 1 | gawk '{print $1}'
                        endcheck="1"
                fi
        done;
done;

## MASTER NODE DISCOVERY
endcheck=1
i=1
while [ "$endcheck" != 0 ]; do
        hname=`host hw-master-${i}`
        hchk=$?
        if [ "$hchk" = "1" ]; then
                endcheck="0"
        else
                echo "$hname" | head -n 1 | gawk '{print $1}'
                endcheck="1"
        fi
        i=$((i+1))
done;
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
utilfqdn=`cat host_list | grep hdf-utility-1`
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
        scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/node_prep.sh opc@$hostfqdn:~/
        scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/tune.sh opc@$hostfqdn:~/
	scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/ambari_agent.sh opc@$hostfqdn:~/
        ## Set Execute Flag on scripts
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn 'chmod +x *.sh'
        ## Execute Node Prep
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn 'sudo ./node_prep.sh &'
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn "sudo systemctl stop firewalld"
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn "sudo systemctl disable firewalld"
        ## Master Setup Files get copied here
        if [ $host = "hdf-utility-1" ]; then
                echo -e "\tCopying Master Setup Files..."
                scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/ambari_setup.sh opc@$hostfqdn:~/
                scp -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa /home/opc/.ssh/id_rsa opc@$hostfqdn:~/.ssh/
                ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /home/opc/.ssh/id_rsa opc@$hostfqdn "chmod 0600 .ssh/id_rsa"
	fi
        echo -e "\tDone initializing $host.\n\n"
done;
## End Worker Node Setup
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
echo -e "--------------------------------------------------------------------"
echo -e "---------------------CLUSTER SETUP COMPLETE-------------------------"
echo -e "--------------------------------------------------------------------"
