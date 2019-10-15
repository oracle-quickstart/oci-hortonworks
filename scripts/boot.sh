#!/bin/bash
utilfqdn=`curl -L http://169.254.169.254/opc/v1/instance/metadata/ambari_server`

LOG_FILE="/var/log/hortonworks-OCI-initialize.log"

## logs everything to the $LOG_FILE
log() {
  echo "$(date) [${EXECNAME}]: $*" >> "${LOG_FILE}"
}

# Ambari Agent Install - set version to match Ambari Server version
# HDP 3.1.0.0 = Ambari 2.7.3.0
# HDP 2.6.5.0 = Ambari 2.6.2.2
ambari_version=`curl -L http://169.254.169.254/opc/v1/instance/metadata/ambari_version`
hdp_version=`curl -L http://169.254.169.254/opc/v1/instance/metadata/hdp_version`
hdp_major_version=`echo $hdp_version | cut -d '.' -f 1`
hdp_utils_version=`curl -L http://169.254.169.254/opc/v1/instance/metadata/hdp_utils_version`

# Configuration needed to automate node scale-up as part of bootstrapping
CLUSTER_NAME=`curl -L http://169.254.169.254/opc/v1/instance/metadata/cluster_name`
ambari_login="hdpadmin"
ambari_password="somepassword"
deployment_type=`curl -L http://169.254.169.254/opc/v1/instance/metadata/deployment_type`

EXECNAME="TUNING"
log "->Start"
#
# HOST TUNINGS
# 

# Add /etc/hosts entries
wct=`curl -L http://169.254.169.254/opc/v1/instance/metadata/worker_node_count`
AD=`curl -L http://169.254.169.254/opc/v1/instance/metadata/AD`
for w in `seq 1 ${wct}`; do 
	host hw-worker-${w}.private${AD}.hwvcn.oraclevcn.com | gawk '{print $4" "$1}' >> /etc/hosts
done;
for m in `seq 1 3`; do 
	host hw-master-${m}.private${AD}.hwvcn.oraclevcn.com | gawk '{print $4" "$1}' >> /etc/hosts
done;

# Disable SELinux
sed -i.bak 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Make resolv.conf immutable
chattr +i /etc/resolv.conf

log "-> Install NTP"
yum install ntp -y >> $LOG_FILE
ntpdate 169.254.169.254 >> $LOG_FILE
sed -i 's/^server/#server/g' /etc/ntp.conf
echo "server 169.254.169.254 iburst" >> /etc/ntp.conf
systemctl start ntpd >> $LOG_FILE
systemctl enable ntpd
systemctl stop chronyd
systemctl disable chronyd
yum remove chrony -y
timedatectl set-ntp true

EXECNAME="JAVA"
log "->INSTALL"
## Install Java & Kerberos client
yum install java-1.8.0-openjdk.x86_64 -y

if [ $deployment_type = "simple" ]; then 
	sleep .001
else
EXECNAME="KERBEROS"
log "->INSTALL"
yum install krb5-workstation -y
log "->krb5.conf"
## Configure krb5.conf
kdc_server=${utilfqdn}
kdc_fqdn=${utilfqdn}
realm="hadoop.com"
REALM="HADOOP.COM"
log "-> CONFIG"
rm -f /etc/krb5.conf
cat > /etc/krb5.conf << EOF
# Configuration snippets may be placed in this directory as well
includedir /etc/krb5.conf.d/

[libdefaults]
 default_realm = ${REALM}
 dns_lookup_realm = false
 dns_lookup_kdc = false
 rdns = false
 ticket_lifetime = 24h
 renew_lifetime = 7d  
 forwardable = true
 udp_preference_limit = 1000000
 default_tkt_enctypes = rc4-hmac 
 default_tgs_enctypes = rc4-hmac
 permitted_enctypes = rc4-hmac 

[realms]
    ${REALM} = {
        kdc = ${kdc_fqdn}:88
        admin_server = ${kdc_fqdn}:749
        default_domain = ${realm}
    }

[domain_realm]
    .${realm} = ${REALM}
     ${realm} = ${REALM}
    bastion1.hwvcn.oraclevcn.com = ${REALM}
    .bastion1.hwvcn.oraclevcn.com = ${REALM}
    bastion2.hwvcn.oraclevcn.com = ${REALM}
    .bastion2.hwvcn.oraclevcn.com = ${REALM}
    bastion3.hwvcn.oraclevcn.com = ${REALM}
    .bastion3.hwvcn.oraclevcn.com = ${REALM}
    .public1.hwvcn.oraclevcn.com = ${REALM}
    public1.hwvcn.oraclevcn.com = ${REALM}
    .public2.hwvcn.oraclevcn.com = ${REALM}
    public2.hwvcn.oraclevcn.com = ${REALM}
    .public3.hwvcn.oraclevcn.com = ${REALM}
    public3.hwvcn.oraclevcn.com = ${REALM}
    .private1.hwvcn.oraclevcn.com = ${REALM}
    private1.hwvcn.oraclevcn.com = ${REALM}
    .private2.hwvcn.oraclevcn.com = ${REALM}
    private2.hwvcn.oraclevcn.com = ${REALM}
    .private3.hwvcn.oraclevcn.com = ${REALM}
    private3.hwvcn.oraclevcn.com = ${REALM}

[kdc]
    profile = /var/kerberos/krb5kdc/kdc.conf

[logging]
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmin.log
    default = FILE:/var/log/krb5lib.log
EOF
fi

EXECNAME="TUNING"
log "->OS"
## Disable Transparent Huge Pages
echo never | tee -a /sys/kernel/mm/transparent_hugepage/enabled
echo "echo never | tee -a /sys/kernel/mm/transparent_hugepage/enabled" | tee -a /etc/rc.local

## Set vm.swappiness to 1
echo vm.swappiness=0 | tee -a /etc/sysctl.conf
echo 0 | tee /proc/sys/vm/swappiness

## Tune system network performance
echo net.ipv4.tcp_timestamps=0 >> /etc/sysctl.conf
echo net.ipv4.tcp_sack=1 >> /etc/sysctl.conf
echo net.core.rmem_max=12582912 >> /etc/sysctl.conf
echo net.core.wmem_max=4194304 >> /etc/sysctl.conf
echo net.core.rmem_default=4194304 >> /etc/sysctl.conf
echo net.core.wmem_default=4194304 >> /etc/sysctl.conf
echo net.core.optmem_max=4194304 >> /etc/sysctl.conf
echo net.ipv4.tcp_rmem="4096 87380 4194304" >> /etc/sysctl.conf
echo net.ipv4.tcp_wmem="4096 87380 4194304" >> /etc/sysctl.conf
echo net.ipv4.tcp_low_latency=1 >> /etc/sysctl.conf

## Tune File System options
sed -i "s/defaults        1 1/defaults,noatime        0 0/" /etc/fstab

log "->SSH"
## Enable root login via SSH key
cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.bak
cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys

## Set Limits
echo "hdfs  -       nofile  32768
hdfs  -       nproc   2048
hbase -       nofile  32768
hbase -       nproc   2048" >> /etc/security/limits.conf
ulimit -n 262144

log "->FirewallD"
systemctl stop firewalld
systemctl disable firewalld

master_check=`hostname | grep master`
master_chk=`echo -e $?`
if [ $master_chk = "0" ]; then 
	EXECNAME="MYSQL Server"
	log "->Install"
	wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
	rpm -ivh mysql-community-release-el7-5.noarch.rpm
fi

EXECNAME="Ambari Agent"
log "->Install"

wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/${ambari_version}/ambari.repo -O /etc/yum.repos.d/ambari.repo
yum install ambari-agent -y >> ${LOG_FILE}
wget -nv http://public-repo-1.hortonworks.com/HDP/centos7/${hdp_major_version}.x/updates/${hdp_version}/hdp.repo -O /etc/yum.repos.d/hdp.repo
wget -nv http://public-repo-1.hortonworks.com/HDP-UTILS-${hdp_utils_version}/repos/centos7/hdp-utils.repo -O /etc/yum.repos.d/hdp-utils.repo
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip"
unzip -o -j -q jce_policy-8.zip -d /usr/jdk64/jdk1.8.0_*/jre/lib/security/

# Modify /etc/ambari-agent/conf/ambari-agent.ini
sed -i "s/localhost/${utilfqdn}/g" /etc/ambari-agent/conf/ambari-agent.ini
sed -i -e $'s/\[security\]/\[security\]\\nforce_https_protocol=PROTOCOL_TLSv1_2/g' /etc/ambari-agent/conf/ambari-agent.ini
log"->Startup"
service ambari-agent start >> ${LOG_FILE}


EXECNAME="OCI HDFS Connector"
log "->Download"
mkdir OCI
cd OCI
wget https://github.com/oracle/oci-hdfs-connector/releases/download/v2.7.7.2/oci-hdfs.zip
unzip oci-hdfs.zip
javaver=`alternatives --list | grep ^java`
javapath=`echo $javaver | gawk '{print $3}'| cut -d '/' -f 1-6`
echo 'java.security.Security.setProperty(\"networkaddress.cache.ttl\" , \"60\");' >>  $javapath/lib/security/java.security
cp lib/*.jar /usr/hdp/${hdp_major_version}.*/hadoop-mapreduce/lib/ 
cd ~

## Post Tuning Execution Below

#
# DISK SETUP
#

vol_match() {
case $i in
	1) disk="oraclevdb";;
	2) disk="oraclevdc";;
	3) disk="oraclevdd";;
	4) disk="oraclevde";;
	5) disk="oraclevdf";;
	6) disk="oraclevdg";;
	7) disk="oraclevdh";;
	8) disk="oraclevdi";;
	9) disk="oraclevdj";;
	10) disk="oraclevdk";;
	11) disk="oraclevdl";;
	12) disk="oraclevdm";;
	13) disk="oraclevdn";;
	14) disk="oraclevdo";;
	15) disk="oraclevdp";;
	16) disk="oraclevdq";;
	17) disk="oraclevdr";;
	18) disk="oraclevds";;
	19) disk="oraclevdt";;
	20) disk="oraclevdu";;
	21) disk="oraclevdv";;
	22) disk="oraclevdw";;
	23) disk="oraclevdx";;
	24) disk="oraclevdy";;
	25) disk="oraclevdz";;
	26) disk="oraclevdab";;
	27) disk="oraclevdac";;
	28) disk="oraclevdad";;
	29) disk="oraclevdae";;
	30) disk="oraclevdaf";;
	31) disk="oraclevdag";;
esac
}

iscsi_setup() {
        log "-> ISCSI Volume Setup - Volume ${i} : IQN ${iqn[$n]}"
        iscsiadm -m node -o new -T ${iqn[$n]} -p 169.254.2.${n}:3260
        log "--> Volume ${iqn[$n]} added"
        iscsiadm -m node -o update -T ${iqn[$n]} -n node.startup -v automatic
        log "--> Volume ${iqn[$n]} startup set"
        iscsiadm -m node -T ${iqn[$n]} -p 169.254.2.${n}:3260 -l
        log "--> Volume ${iqn[$n]} done"
}

iscsi_target_only(){
	log "-->Logging into Volume ${iqn[$n]}"
	su - opc -c "sudo iscsiadm -m node -T ${iqn[$n]} -p 169.254.2.${n}:3260 -l"
}

## Look for all ISCSI devices in sequence, finish on first failure
EXECNAME="ISCSI"
log "- Begin Block Volume Detection Loop -"
detection_flag="0"
while [ "$detection_flag" = "0" ]; do
	detection_done="0"
	log "-- Detecting Block Volumes --"
	for i in `seq 2 33`; do
		if [ $detection_done = "0" ]; then
			iscsiadm -m discoverydb -D -t sendtargets -p 169.254.2.$i:3260 2>&1 2>/dev/null
			iscsi_chk=`echo -e $?`
			if [ $iscsi_chk = "0" ]; then
				# IQN list is important set up this array with discovered IQNs
				iqn[${i}]=`iscsiadm -m discoverydb -D -t sendtargets -p 169.254.2.${i}:3260 | gawk '{print $2}'` 
				log "-> Discovered volume $((i-1)) - IQN: ${iqn[${i}]}"
				continue
			else
				volume_count="${#iqn[@]}"
				log "--> Discovery Complete - ${#iqn[@]} volumes found"
				detection_done="1"
			fi
		fi
	done;
	## Now let's do this again after a 30 second sleep to ensure consistency in case this ran in the middle of volume attachments
	sleep 30
	sanity_detection_done="0"
	sanity_volume_count="0"
	for i in `seq 2 33`; do
                if [ $sanity_detection_done = "0" ]; then
                        iscsiadm -m discoverydb -D -t sendtargets -p 169.254.2.$i:3260 2>&1 2>/dev/null
                        iscsi_chk=`echo -e $?`
                        if [ $iscsi_chk = "0" ]; then
                                # IQN list is important set up this array with discovered IQNs
                                siqn[${i}]=`iscsiadm -m discoverydb -D -t sendtargets -p 169.254.2.${i}:3260 | gawk '{print $2}'`
                                continue
                        else
                                sanity_volume_count="${#siqn[@]}"
                                log "--> Sanity Discovery Complete - ${#siqn[@]} volumes found"
                                sanity_detection_done="1"
                        fi
                fi
        done;
	if [ "$volume_count" = "0" ]; then 
		if [ "$volume_count" = "$sanity_volume_count" ]; then 
			log "-- $volume_count Block Volumes found, done."
			detection_flag="1"
		else
			log "-- Sanity Check Failed - $sanity_volume_count Volumes found, $volume_count on first run.  Re-running --"
			sleep 30
			continue
		fi
	elif [ "$volume_count" != "$sanity_volume_count" ]; then
		log "-- Sanity Check Failed - $sanity_volume_count Volumes found, $volume_count on first run.  Re-running --"
		sleep 15
		continue
	elif [ "$volume_count" = "$sanity_volume_count" ]; then 
		log "-- Setup for ${#iqn[@]} Block Volumes --"
		for i in `seq 1 ${#iqn[@]}`; do
			n=$((i+1))
			iscsi_setup
		done;
		detection_flag="1"
	else
		log "-- Repeating Detection --"
		continue
	fi
done;

EXECNAME="boot.sh - DISK PROVISIONING"
## Primary Disk Mounting Function
data_mount () {
  log "-->Mounting /dev/$disk to /data$dcount"
  mkdir -p /data$dcount
  mount -o noatime,barrier=1 -t ext4 /dev/$disk /data$dcount
  UUID=`lsblk -no UUID /dev/$disk`
  echo "UUID=$UUID   /data$dcount    ext4   defaults,noatime,discard,barrier=0 0 1" | tee -a /etc/fstab
}

block_data_mount () {
  log "-->Mounting /dev/oracleoci/$disk to /data$dcount"
  mkdir -p /data$dcount
  mount -o noatime,barrier=1 -t ext4 /dev/oracleoci/$disk /data$dcount
  UUID=`lsblk -no UUID /dev/oracleoci/$disk`
  echo "UUID=$UUID   /data$dcount    ext4   defaults,_netdev,nofail,noatime,discard,barrier=0 0 2" | tee -a /etc/fstab
}

EXECNAME="DISK SETUP"
## Check for x>0 devices
log "->Checking for disks..."
nvcount="0"
bvcount="0"
## Execute - will format all devices except sda for use as data disks in HDFS
dcount=0
for disk in `ls /dev/ | grep nvme | grep n1`; do
	log "-->Processing /dev/$disk"
  	mke2fs -F -t ext4 -b 4096 -E lazy_itable_init=1 -O sparse_super,dir_index,extent,has_journal,uninit_bg -m1 /dev/$disk
    	data_mount
	dcount=$((dcount+1))
done;

raid_disk_setup() {
parted -a optimal /dev/oracleoci/$disk mklabel msdos
parted -a optimal /dev/oracleoci/$disk mkpart primary 1MiB 751GB
parted -a optimal /dev/oracleoci/$disk set 1 raid on
}

worker_check=`hostname | grep worker`
is_worker=`echo -e $?`
if [ $is_worker = "0" ]; then 
	log "--->Worker Detected"
fi
if [ ${#iqn[@]} -gt 0 ]; then 
for i in `seq 1 ${#iqn[@]}`; do
	n=$((i+1))
	dsetup="0"
	while [ $dsetup = "0" ]; do
		vol_match
		log "-->Checking /dev/oracleoci/$disk"
		if [ -h /dev/oracleoci/$disk ]; then
			case $disk in
				oraclevdb|oraclevdc|oraclevdd|oraclevde)
				if [ $is_worker = 0 ]; then 
					raid_disk_setup >> $LOG_FILE
				else
					mke2fs -F -t ext4 -b 4096 -E lazy_itable_init=1 -O sparse_super,dir_index,extent,has_journal,uninit_bg -m1 /dev/oracleoci/$disk
	                                block_data_mount
        	                        dcount=$((dcount+1))
				fi
				;;
				*)
				mke2fs -F -t ext4 -b 4096 -E lazy_itable_init=1 -O sparse_super,dir_index,extent,has_journal,uninit_bg -m1 /dev/oracleoci/$disk
				block_data_mount
                		dcount=$((dcount+1))
				;;
			esac
			/sbin/tune2fs -i0 -c0 /dev/oracleoci/$disk
			dsetup="1"
		else
			log "--->${disk} not found, running ISCSI again."
			iscsi_target_only
			sleep 5
		fi
	done;
done;
fi
if [ $is_worker = 0 ]; then 
	EXECNAME="RAID SETUP"
	log "->Setup LVM"
	vgcreate RAID0 /dev/oracleoci/oraclevd[b-e]1 >> $LOG_FILE
	sleep 1
	raid_setup="1"
	lvcount="0"
	while [ $raid_setup = "1" ]; do 
		# Check to ensure all devices were added
		pv_check=`pvs | wc -l`
		if [ $pv_check != "5" ]; then 
			log "--> LVM SETUP FAILURE DETECTED, RETRYING"
			vgremove RAID0 >> $LOG_FILE
			sleep 1
			vgcreate RAID0 /dev/oracleoci/oraclevd[b-e]1 >> $LOG_FILE
			sleep 1
		else
			raid_setup="0"
		fi
		lvcount=$((lvcount+1))
		if [ $lvcount = "10" ]; then 
			log "--> 10 CONCURRENT LVM FAILURES, EXITING LOOP.  CHECK BLOCK VOLUME ATTACHMENTS, RUN RAID SETUP MANUALLY"
			raid_setup="0"
		fi
	done;
	lvcreate --type raid0 -l 100%FREE --stripes 4 --stripesize 64 -n hadoop RAID0 >> $LOG_FILE
	log "->Mkfs"
	mkfs.ext4 /dev/RAID0/hadoop >> $LOG_FILE
	mkdir -p /hadoop
	mount /dev/RAID0/hadoop /hadoop >> $LOG_FILE
	echo "/dev/RAID0/hadoop                /hadoop              ext4    defaults,_netdev,noatime,discard,barrier=0         0 0" | tee -a /etc/fstab
	mkdir /hadoop/tmp
	chmod 1777 /hadoop/tmp
	mount -B /tmp /hadoop/tmp
	chmod 1777 /tmp
fi

EXECNAME="CLUSTER ACTIONS"
hostfqdn=`hostname -f`
log "->Check for Existing Cluster"
cluster_check=`curl --connect-timeout 5 -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X GET https://${utilfqdn}:9443/api/v1/clusters/${CLUSTER_NAME} | wc -l`
if [ $cluster_check = "0" ]; then 
	log "->Ambari query for Cluster ${CLUSTER_NAME} timeout.  Assuming this is new build, skipping Host deployment into cluster."
elif [ $cluster_check -gt 20 ]; then
        log "->Add Kerberos Credentials"
        curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X PUT -d '{ "Credential" : { "principal" : "ambari/admin@HADOOP.COM", "key" : "somepassword", "type" : "temporary" }}' https://${ambari_ip}:9443/api/v1/clusters/${CLUSTER_NAME}/credentials/kdc.admin.credential
        sleep 1
	log "->Add Host to Cluster ${CLUSTER_NAME}"
	curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X POST https://${utilfqdn}:9443/api/v1/clusters/${CLUSTER_NAME}/hosts/${hostfqdn}
	sleep 1
	log "->Set Host Components"
	short_hostname=`hostname`
	echo -e $short_hostname | grep worker
	datanode_check=`echo -e $?`
	if [ ${datanode_check} = "0" ]; then
		host_component[0]="DATANODE"
		host_component[1]="NODEMANAGER"
		host_component[2]="METRICS_MONITOR"
		host_component[3]="HBASE_REGIONSERVER"
		host_component[4]="ZOOKEEPER_CLIENT"
	else
		host_component[0]="METRICS_MONITOR"
	fi
	for component in `echo ${host_component[*]}`; do 
		curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X POST https://${utilfqdn}:9443/api/v1/clusters/${CLUSTER_NAME}/hosts/${hostfqdn}/host_components/${component}
		sleep 1
	done;
	 for component in `echo ${host_component[*]}`; do
                curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X PUT -d '{"HostRoles": {"state": "INSTALLED"}}' https://${utilfqdn}:9443/api/v1/clusters/${CLUSTER_NAME}/hosts/${hostfqdn}/host_components/${component}
                sleep 1
        done;
else
	log"->Cluster ${CLUSTER_NAME} not found. Skipping Host deployment into cluster."
fi
EXECNAME="END"
log "->DONE"
