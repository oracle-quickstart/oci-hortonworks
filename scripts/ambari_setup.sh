#!/bin/bash
#Extract Utility server from metadata
utilfqdn=`curl -L http://169.254.169.254/opc/v1/instance/metadata/ambari_server`

# Change this prior to deployment
mysql_db_password="somepassword"
ambari_user="ambari"
ambari_db_password="somepassword"
mysql_admin_user="mysqladmin"
msyql_admin_password="somepassword"
# Set Ambari Version to match supported HDP version
# HDP 3.1.0.0 = Ambari 2.7.3.0
# HDP 2.6.5.0 = Ambari 2.7.2.2
ambari_version=`curl -L http://169.254.169.254/opc/v1/instance/metadata/ambari_version`
hdp_version=`curl -L http://169.254.169.254/opc/v1/instance/metadata/hdp_version`
hdp_major_version=`echo $hdp_version | cut -d '.' -f 1`
hdp_utils_version=`curl -L http://169.254.169.254/opc/v1/instance/metadata/hdp_utils_version`
#

LOG_FILE="/var/log/hortonworks-OCI-initialize.log"

## logs everything to the $LOG_FILE
log() {
  echo "$(date) [${EXECNAME}]: $*" >> "${LOG_FILE}"
}

gen_mysql () {
cat << EOF 
CREATE USER '${ambari_user}'@'%' IDENTIFIED BY '${ambari_db_password}';
GRANT ALL PRIVILEGES ON *.* TO '${ambari_user}'@'%';
CREATE USER '${ambari_user}'@'localhost' IDENTIFIED BY '${ambari_db_password}';
GRANT ALL PRIVILEGES ON *.* TO '${ambari_user}'@'localhost';
CREATE USER '${ambari_user}'@'${utilfqdn}' IDENTIFIED BY '${ambari_db_password}';
GRANT ALL PRIVILEGES ON *.* TO '${ambari_user}'@'${utilfqdn}';
GRANT ALL PRIVILEGES ON *.* to '${mysql_admin_user}'@'%' IDENTIFIED BY '${mysql_admin_password}' WITH GRANT OPTION;
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF
}

EXECNAME="Ambari Certificate"
mkdir -p /etc/ambari-server/certs
cd /etc/ambari-server/certs
log "->Generate & Deploy"
openssl genrsa -out ${utilfqdn}.key 2048
# This should be customized to your organization
openssl req -new -key ${utilfqdn}.key -out ${utilfqdn}.csr -subj "/C=US/ST=Washington/L=Seattle/O=OCI/OU=Hortonworks/CN=${utilfqdn}"
openssl x509 -req -days 365 -in ${utilfqdn}.csr -signkey ${utilfqdn}.key -out ${utilfqdn}.crt

EXECNAME="MYSQL Server"
log "->Install"
wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
rpm -ivh mysql-community-release-el7-5.noarch.rpm
yum install mysql-server mysql-connector-java* epel-release -y
log "->Tuning"
head -n -6 /etc/my.cnf >> /etc/my.cnf.new
mv /etc/my.cnf /etc/my.cnf.rpminstall
mv /etc/my.cnf.new /etc/my.cnf
echo -e "transaction_isolation = READ-COMMITTED\n\
read_buffer_size = 2M\n\
read_rnd_buffer_size = 16M\n\
sort_buffer_size = 8M\n\
join_buffer_size = 8M\n\
query_cache_size = 64M\n\
query_cache_limit = 8M\n\
query_cache_type = 1\n\
thread_stack = 256K\n\
thread_cache_size = 64\n\
max_connections = 700\n\
key_buffer_size = 32M\n\
max_allowed_packet = 32M\n\
log_bin=/var/lib/mysql/mysql_binary_log\n\
server_id=1\n\
binlog_format = mixed\n\
\n\
# InnoDB Settings\n\
innodb_file_per_table = 1\n\
innodb_flush_log_at_trx_commit = 2\n\
innodb_log_buffer_size = 64M\n\
innodb_thread_concurrency = 8\n\
innodb_buffer_pool_size = 4G\n\
innodb_flush_method = O_DIRECT\n\
innodb_log_file_size = 512M\n\
\n\
[mysqld_safe]\n\
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid \n\
\n\
sql_mode=STRICT_ALL_TABLES\n\
" >> /etc/my.cnf
log "-->Database setup"
systemctl enable mysqld
systemctl start mysqld
gen_mysql > mysql-setup.sql
#execute sql file
mysql -u root < mysql-setup.sql
#change Mysql password to DB Password
mysqladmin -u root password ${mysql_db_password}

EXECNAME="Ambari Server & Agent"
log "->Install"
# Ambari Agent Install
wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/${ambari_version}/ambari.repo -O /etc/yum.repos.d/ambari.repo
yum install ambari-server ambari-agent -y
# Bootstrap MySQL for Ambari
mysql -u ${ambari_user} -p${ambari_db_password} -e 'CREATE DATABASE ambari'
mysql -u ${ambari_user} -p${ambari_db_password} -D ambari < /var/lib/ambari-server/resources/Ambari-DDL-MySQL-CREATE.sql
ambari-server setup -s --databasehost=${utilfqdn} --database=mysql --databaseport=3306 --databasename=ambari --databaseusername=${ambari_user} --databasepassword=${ambari_db_password}
ambari-server setup  --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar
ambari-server setup-security --security-option=setup-https --api-ssl=true --api-ssl-port=8443 --import-cert-path=/etc/ambari-server/certs/${utilfqdn}.crt --import-key-path=/etc/ambari-server/certs/${utilfqdn}.key --pem-password=
sed -i 's/client.api.ssl.port=8443/client.api.ssl.port=9443/g' /etc/ambari-server/conf/ambari.properties
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip"
unzip -o -j -q jce_policy-8.zip -d /usr/jdk64/jdk1.8.0_*/jre/lib/security/
service ambari-server start
wget -nv http://public-repo-1.hortonworks.com/HDP/centos7/${hdp_major_version}.x/updates/${hdp_version}/hdp.repo -O /etc/yum.repos.d/hdp.repo
wget -nv http://public-repo-1.hortonworks.com/HDP-UTILS-${hdp_utils_version}/repos/centos7/hdp-utils.repo -O /etc/yum.repos.d/hdp-utils.repo

# Modify /etc/ambari-agent/conf/ambari-agent.ini
sed -i "s/localhost/${utilfqdn}/g" /etc/ambari-agent/conf/ambari-agent.ini
sed -i -e $'s/\[security\]/\[security\]\\nforce_https_protocol=PROTOCOL_TLSv1_2/g' /etc/ambari-agent/conf/ambari-agent.ini
log"->Startup"
service ambari-agent start

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
## Install Java
yum install java-1.8.0-openjdk.x86_64 -y

if [ $deployment_type = "simple" ]; then
	sleep .001
else
## KERBEROS INSTALL
EXECNAME="KERBEROS"
log "-> INSTALL"
yum -y install krb5-workstation
yum -y install krb5-server krb5-libs krb5-workstation
KERBEROS_PASSWORD="SOMEPASSWORD"
AMBARI_USER_PASSWORD="somepassword"
kdc_server=$(hostname)
kdc_fqdn=`host $kdc_server | gawk '{print $1}'`
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


rm -f /var/kerberos/krb5kdc/kdc.conf
cat > /var/kerberos/krb5kdc/kdc.conf << EOF
default_realm = ${REALM}

[kdcdefaults]
    v4_mode = nopreauth
    kdc_ports = 0

[realms]
    ${REALM} = {
        kdc_ports = 88
        admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
        database_name = /var/kerberos/krb5kdc/principal
        acl_file = /var/kerberos/krb5kdc/kadm5.acl
        key_stash_file = /var/kerberos/krb5kdc/stash
        max_life = 10h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        master_key_type = des3-hmac-sha1
        supported_enctypes = rc4-hmac:normal 
        default_principal_flags = +preauth
    }
EOF

rm -f /var/kerberos/krb5kdc/kadm5.acl
cat > /var/kerberos/krb5kdc/kadm5.acl << EOF
*/admin@${REALM}    *
ambari/admin@${REALM}   *
EOF

kdb5_util create -r ${REALM} -s -P ${KERBEROS_PASSWORD}

echo -e "addprinc root/admin\n${KERBEROS_PASSWORD}\n${KERBEROS_PASSWORD}\naddprinc ambari/admin\n${AMBARI_USER_PASSWORD}\n${AMBARI_USER_PASSWORD}\nktadd -k /var/kerberos/krb5kdc/kadm5.keytab kadmin/admin\nktadd -k /var/kerberos/krb5kdc/kadm5.keytab kadmin/changepw\nexit\n" | kadmin.local -r ${REALM}
log "-> START"
systemctl start krb5kdc.service
systemctl start kadmin.service
systemctl enable krb5kdc.service
systemctl enable kadmin.service
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
echo net.core.rmem_max=4194304 >> /etc/sysctl.conf
echo net.core.wmem_max=4194304 >> /etc/sysctl.conf
echo net.core.rmem_default=4194304 >> /etc/sysctl.conf
echo net.core.wmem_default=4194304 >> /etc/sysctl.conf
echo net.core.optmem_max=4194304 >> /etc/sysctl.conf
echo net.ipv4.tcp_rmem="4096 87380 4194304" >> /etc/sysctl.conf
echo net.ipv4.tcp_wmem="4096 65536 4194304" >> /etc/sysctl.conf
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

if [ ${#iqn[@]} -gt 0 ]; then 
for i in `seq 1 ${#iqn[@]}`; do
	n=$((i+1))
	dsetup="0"
	while [ $dsetup = "0" ]; do
		vol_match
		log "-->Checking /dev/oracleoci/$disk"
		if [ -h /dev/oracleoci/$disk ]; then
			mke2fs -F -t ext4 -b 4096 -E lazy_itable_init=1 -O sparse_super,dir_index,extent,has_journal,uninit_bg -m1 /dev/oracleoci/$disk
			block_data_mount
                	dcount=$((dcount+1))
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
log "->DONE"
