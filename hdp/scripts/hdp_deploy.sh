#!/bin/bash
# Ambari Setup Script

## Util FQDN is the Public IP of the Ambari host
ambari_ip=$1
## AD is needed to set proper subnet for host topology
ad=$2
# Worker Shape - used for tuning
worker_shape=$3
# Number of Block Volume HDFS Disks
block_disks=$4
# Number of Workers
wc=$5


if [ -z $5 ]; then
	echo "Usage:\n"
	echo "./hdp_install.sh <ambari_public_ip> <availability_domain> <worker_shape> <block_volume_hdfs_disk_count> <worker_count>"
	exit
fi

case $worker_shape in
	BM.Standard.E2.64)
	wprocs=64
        hdfs_disks=${block_disks}
        data_tiering="false"
	;;

	BM.DenseIO2.52)
	wprocs=52
	nvme_disks=8
	hdfs_disks=$((${nvme_disks}+${block_disks}))
	data_tiering="true"
	;;

	BM.Standard2.52|BM.GPU3.8)
	wprocs=52
	hdfs_disks=${block_disks}
	data_tiering="false"
	;;

	BM.HPC2.36)
	wprocs=36
	nvme_disks=1
        hdfs_disks=$((${nvme_disks}+${block_disks}))
	data_tiering="true"
	;;

	BM.DenseIO1.36)
	wprocs=36
	hdfs_disks=$((9+${block_disks}))
	data_tiering="true"
	;;

	BM.Standard1.36)
	wprocs=36
	hdfs_disks=${block_disks}
	data_tiering="false"
	;;

	BM.GPU2.2)
	wprocs=28
        hdfs_disks=${block_disks}
        data_tiering="false"
        ;;

        VM.DenseIO2.24)
	wprocs=24
	nvme_disks=4
        hdfs_disks=$((${nvme_disks}+${block_disks}))
	data_tiering="true"
	;;

	VM.Standard2.24|VM.GPU3.4)
        wprocs=24
        hdfs_disks=${block_disks}
        data_tiering="false"
        ;;

	VM.DenseIO2.16)
	wprocs=16
	nvme_disks=2
        hdfs_disks=$((${nvme_disks}+${block_disks}))
	data_tiering="true"
	;;

	VM.DenseIO1.16)
	wprocs=16
	nvme_disks=4
        hdfs_disks=$((${nvme_disks}+${block_disks}))
        data_tiering="true"
        ;;

	VM.Standard2.16|VM.Standard1.16)
	wprocs=16
        hdfs_disks=${block_disks}
        data_tiering="false"
	;;

	VM.GPU2.1|VM.GPU3.2)
	wprocs=12
	hdfs_disks=${block_disks}
	data_tiering="false"
	;;

	VM.DenseIO2.8)
	wprocs=8
	nvme_disks=1
        hdfs_disks=$((${nvme_disks}+${block_disks}))
	data_tiering="true"
	;;

	VM.DenseIO1.8)
	wprocs=8
	nvme_disks=2
        hdfs_disks=$((${nvme_disks}+${block_disks}))
        data_tiering="true"
        ;;	

	VM.Standard2.8|VM.Standard1.8|VM.StandardE2.8)
	wprocs=8
        hdfs_disks=${block_disks}
        data_tiering="false"
	;;

	VM.GPU3.1)
	wprocs=6
	hdfs_disks=${block_disks}
	data_tiering="false"
	;;

	*)
	echo "Unsupported Worker Shape ${worker_shape} - validate this is a supported OCI shape for use as a Worker Node."
	exit
	;;

esac	
	

	
# Set some global variables first

## HDP Version - Modify these to install specific version
HDP_version="2.6.5.0"
UTILS_version="1.1.0.22"

## Cluster Info 
CLUSTER_NAME="TestCluster"
# Set a new admin account
ambari_login="hdpadmin"
ambari_password="somepassword"

# Host Mapping needed for cluster config
utilfqdn="hw-utility-1.public${ad}.hwvcn.oraclevcn.com"
master1fqdn="hw-master-1.private${ad}.hwvcn.oraclevcn.com"
master2fqdn="hw-master-2.private${ad}.hwvcn.oraclevcn.com"
bastionfqdn="hw-bastion1.bastion${ad}.hwvcn.oraclevcn.com"

##
## Functions
##

create_random_password(){
  perl -le 'print map { ("a".."z", "A".."Z", 0..9)[rand 62] } 1..10'
}

admin_password_json(){
cat << EOF
{
	"Users/user_name": "admin",
	"Users/password": "${admin_password}",
	"Users/active": "false"
	}
EOF
}

new_admin(){
cat << EOF
{
	"Users/user_name": "${ambari_login}",
	"Users/password": "${ambari_password}",
	"Users/active": "true",
	"Users/admin": "true"
	}
EOF
}

## Detect and generate DFS config for HDFS
create_hdfs_config(){
dc=0
while [ $dc -lt $hdfs_disks ]; do
	if [ $data_tiering = "false" ]; then 
		if [ $dc = 0 ]; then
			dfs=`echo "\"/data${dc}/"`
		elif [ $dc = $((hdfs_disks-1)) ]; then
			dfs=`echo "$dfs,/data${dc}/\""`
		else
		 	dfs=`echo "$dfs,/data${dc}/"`
		fi
		dc=$((dc+1))
	elif [ $data_tiering = "true" ]; then 
                if [ $dc = 0 ]; then
                        dfs=`echo "\"[DISK]/data${dc}/"`
		elif [ $dc -lt $nvme_disks ]; then
			dfs=`echo "$dfs,[DISK]/data${dc}/"`
                elif [ $dc = $((hdfs_disks-1)) ]; then
                        dfs=`echo "$dfs,[ARCHIVE]/data${dc}/\""`
                else
                        dfs=`echo "$dfs,[ARCHIVE]/data${dc}/"`
                fi
                dc=$((dc+1))
	fi
done;
}

## Create Cluster hostmap.json
create_dynamic_hostmap(){
cat << EOF
{
        "blueprint": "${CLUSTER_NAME}",
        "default_password": "hadoop",
        "host_groups": [{
            "name": "master3",
            "hosts": [{ "fqdn": "${utilfqdn}" }]
        }, {
            "name": "master1",
            "hosts": [{ "fqdn": "${master1fqdn}" }]
        }, {
            "name": "master2",
            "hosts": [{ "fqdn": "${master2fqdn}" }]
        }, {
            "name": "datanode",
            "host_count": "${wc}",
	    "host_predicate": "Hosts/cpu_count=${wprocs}"
        }, {
            "name": "bastion",
            "hosts": [{ "fqdn": "${bastionfqdn}" }]
        }],
        "Clusters": {
            "cluster_name": "${CLUSTER_NAME}"
        }
    }
EOF
}

## Create Cluster configuration cluster_config.json
create_cluster_config(){
cat << EOF
{
	"configurations": [
		{ "ams-env" : {
			"properties": {
				"ambari_metrics_user" : "ams",
				"metrics_collector_heapsize" : "512m",
				"metrics_collector_log_dir" : "/var/log/ambari-metrics-collector",
				"metrics_collector_pid_dir" : "/var/run/ambari-metrics-collector",
				"metrics_monitor_log_dir" : "/var/log/ambari-metrics-monitor",
				"metrics_monitor_pid_dir" : "/var/run/ambari-metrics-monitor"
		      }}
		},
		{ "ams-hbase-env" : {
			"properties" : {
			        "hbase_log_dir" : "/var/log/ambari-metrics-collector",
			        "hbase_master_heapsize" : "1024m",
			        "hbase_master_maxperm_size" : "128m",
			        "hbase_master_xmn_size" : "128m",
			        "hbase_pid_dir" : "/var/run/ambari-metrics-collector/",
			        "hbase_regionserver_heapsize" : "1024m",
			        "hbase_regionserver_xmn_max" : "512m",
			        "hbase_regionserver_xmn_ratio" : "0.2",
			        "regionserver_xmn_size" : "256m"
			}}
		},
		{ "ams-hbase-log4j" : {
			"properties" : {
			}}
		},
		{ "ams-hbase-policy" : {
			"properties" : {
 			        "security.admin.protocol.acl" : "*",
  			        "security.client.protocol.acl" : "*",
				"security.masterregion.protocol.acl" : "*"
			}}
		},
		{ "ams-hbase-security-site" : {
			"properties" : {
			        "ams.zookeeper.keytab" : "",
			        "ams.zookeeper.principal" : "",
			        "hadoop.security.authentication" : "",
			        "hbase.coprocessor.master.classes" : "",
			        "hbase.coprocessor.region.classes" : "",
			        "hbase.master.kerberos.principal" : "",
			        "hbase.master.keytab.file" : "",
  			        "hbase.myclient.keytab" : "",
			        "hbase.myclient.principal" : "",
			        "hbase.regionserver.kerberos.principal" : "",
			        "hbase.regionserver.keytab.file" : "",
			        "hbase.security.authentication" : "",
			        "hbase.security.authorization" : "",
			        "hbase.zookeeper.property.authProvider.1" : "",
			        "hbase.zookeeper.property.jaasLoginRenew" : "",
			        "hbase.zookeeper.property.kerberos.removeHostFromPrincipal" : "",
			        "hbase.zookeeper.property.kerberos.removeRealmFromPrincipal" : "",
			        "zookeeper.znode.parent" : ""
			}}
		},
		{ "ams-hbase-site" : {
			"properties" : {
			        "hbase.client.scanner.caching" : "10000",
			        "hbase.client.scanner.timeout.period" : "900000",
			        "hbase.cluster.distributed" : "false",
			        "hbase.hregion.majorcompaction" : "0",
				"hbase.hregion.memstore.block.multiplier" : "4",
				"hbase.hregion.memstore.flush.size" : "134217728",
				"hbase.hstore.blockingStoreFiles" : "200",
				"hbase.hstore.flusher.count" : "2",
				"hbase.local.dir" : "\${hbase.tmp.dir}/local",
				"hbase.master.info.bindAddress" : "0.0.0.0",
				"hbase.master.info.port" : "61310",
				"hbase.master.port" : "61300",
				"hbase.master.wait.on.regionservers.mintostart" : "1",
				"hbase.regionserver.global.memstore.lowerLimit" : "0.3",
				"hbase.regionserver.global.memstore.upperLimit" : "0.35",
				"hbase.regionserver.info.port" : "61330",
				"hbase.regionserver.port" : "61320",
				"hbase.regionserver.thread.compaction.large" : "2",
				"hbase.regionserver.thread.compaction.small" : "3",
				"hbase.replication" : "false",
				"hbase.rootdir" : "file:///var/lib/ambari-metrics-collector/hbase",
				"hbase.snapshot.enabled" : "false",
				"hbase.tmp.dir" : "/var/lib/ambari-metrics-collector/hbase-tmp",
				"hbase.zookeeper.leaderport" : "61388",
				"hbase.zookeeper.peerport" : "61288",
				"hbase.zookeeper.property.clientPort" : "61181",
				"hbase.zookeeper.property.dataDir" : "\${hbase.tmp.dir}/zookeeper",
				"hbase.zookeeper.quorum" : "{{zookeeper_quorum_hosts}}",
				"hfile.block.cache.size" : "0.3",
				"phoenix.groupby.maxCacheSize" : "307200000",
				"phoenix.query.maxGlobalMemoryPercentage" : "15",
				"phoenix.query.spoolThresholdBytes" : "12582912",
				"phoenix.query.timeoutMs" : "1200000",
				"phoenix.sequence.saltBuckets" : "2",
				"phoenix.spool.directory" : "\${hbase.tmp.dir}/phoenix-spool",
				"zookeeper.session.timeout" : "120000",
				"zookeeper.session.timeout.localHBaseCluster" : "20000"
			}}
    		},
		{ "ams-site" : {
			"properties" : {
				"phoenix.query.maxGlobalMemoryPercentage" : "25",
				"phoenix.spool.directory" : "/tmp",
				"timeline.metrics.aggregator.checkpoint.dir" : "/var/lib/ambari-metrics-collector/checkpoint",
				"timeline.metrics.cluster.aggregator.hourly.checkpointCutOffMultiplier" : "2",
				"timeline.metrics.cluster.aggregator.hourly.disabled" : "false",
				"timeline.metrics.cluster.aggregator.hourly.interval" : "3600",
				"timeline.metrics.cluster.aggregator.hourly.ttl" : "31536000",
				"timeline.metrics.cluster.aggregator.minute.checkpointCutOffMultiplier" : "2",
				"timeline.metrics.cluster.aggregator.minute.disabled" : "false",
				"timeline.metrics.cluster.aggregator.minute.interval" : "120",
				"timeline.metrics.cluster.aggregator.minute.timeslice.interval" : "15",
				"timeline.metrics.cluster.aggregator.minute.ttl" : "2592000",
				"timeline.metrics.hbase.compression.scheme" : "SNAPPY",
				"timeline.metrics.hbase.data.block.encoding" : "FAST_DIFF",
				"timeline.metrics.host.aggregator.hourly.checkpointCutOffMultiplier" : "2",
				"timeline.metrics.host.aggregator.hourly.disabled" : "false",
				"timeline.metrics.host.aggregator.hourly.interval" : "3600",
				"timeline.metrics.host.aggregator.hourly.ttl" : "2592000",
				"timeline.metrics.host.aggregator.minute.checkpointCutOffMultiplier" : "2",
				"timeline.metrics.host.aggregator.minute.disabled" : "false",
				"timeline.metrics.host.aggregator.minute.interval" : "120",
				"timeline.metrics.host.aggregator.minute.ttl" : "604800",
				"timeline.metrics.host.aggregator.ttl" : "86400",
				"timeline.metrics.service.checkpointDelay" : "60",
				"timeline.metrics.service.default.result.limit" : "5760",
				"timeline.metrics.service.operation.mode" : "embedded",
				"timeline.metrics.service.resultset.fetchSize" : "2000",
				"timeline.metrics.service.rpc.address" : "0.0.0.0:60200",
				"timeline.metrics.service.webapp.address" : "0.0.0.0:6188"
        		}}
		},
		{ "core-site": {
			"properties": {
				"fs.defaultFS": "hdfs://${CLUSTER_NAME}",
				"ha.zookeeper.quorum" : "%HOSTGROUP::master1%:2181,%HOSTGROUP::master3%:2181,%HOSTGROUP::master2%:2181"
		    	}}
		},
		{ "hdfs-site": {
			"properties" : {
				"dfs.client.failover.proxy.provider.${CLUSTER_NAME}" : "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider",
			        "dfs.ha.automatic-failover.enabled" : "true",
			        "dfs.ha.fencing.methods" : "shell(/bin/true)",
			        "dfs.ha.namenodes.${CLUSTER_NAME}" : "nn1,nn2",
			        "dfs.namenode.http-address" : "%HOSTGROUP::master1%:50070",
			        "dfs.namenode.http-address.${CLUSTER_NAME}.nn1" : "%HOSTGROUP::master1%:50070",
			        "dfs.namenode.http-address.${CLUSTER_NAME}.nn2" : "%HOSTGROUP::master2%:50070",
			        "dfs.namenode.https-address" : "%HOSTGROUP::master1%:50470",
			        "dfs.namenode.https-address.${CLUSTER_NAME}.nn1" : "%HOSTGROUP::master1%:50470",
			        "dfs.namenode.https-address.${CLUSTER_NAME}.nn2" : "%HOSTGROUP::master2%:50470",
			        "dfs.namenode.rpc-address.${CLUSTER_NAME}.nn1" : "%HOSTGROUP::master1%:8020",
			        "dfs.namenode.rpc-address.${CLUSTER_NAME}.nn2" : "%HOSTGROUP::master2%:8020",
			        "dfs.namenode.shared.edits.dir" : "qjournal://%HOSTGROUP::master1%:8485;%HOSTGROUP::master2%:8485/${CLUSTER_NAME}",
			        "dfs.nameservices" : "${CLUSTER_NAME}",
				"dfs.datanode.data.dir" : ${dfs}
    			}}
  		},
		{ "yarn-site" : {
		        "properties" : {
		        	"hadoop.registry.rm.enabled" : "false",
			        "hadoop.registry.zk.quorum" : "%HOSTGROUP::master2%:2181,%HOSTGROUP::master3%:2181,%HOSTGROUP::master1%:2181",
			        "yarn.log.server.url" : "http://%HOSTGROUP::master2%:19888/jobhistory/logs",
				"yarn.resourcemanager.address" : "%HOSTGROUP::master2%:8050",
			        "yarn.resourcemanager.zk-address" : "%HOSTGROUP::master2%:2181,%HOSTGROUP::master3%:2181,%HOSTGROUP::master1%:2181",
			        "yarn.resourcemanager.admin.address" : "%HOSTGROUP::master2%:8141",
			        "yarn.resourcemanager.cluster-id" : "yarn-cluster",
			        "yarn.resourcemanager.ha.automatic-failover.zk-base-path" : "/yarn-leader-election",
			        "yarn.resourcemanager.ha.enabled" : "true",
			        "yarn.resourcemanager.ha.rm-ids" : "rm1,rm2",
				"yarn.resourcemanager.hostname" : "%HOSTGROUP::master2%",
			        "yarn.resourcemanager.hostname.rm1" : "%HOSTGROUP::master2%",
				"yarn.resourcemanager.hostname.rm2" : "%HOSTGROUP::master1%",
			        "yarn.resourcemanager.recovery.enabled" : "true",
			        "yarn.resourcemanager.resource-tracker.address" : "%HOSTGROUP::master2%:8025",
			        "yarn.resourcemanager.scheduler.address" : "%HOSTGROUP::master2%:8030",
			        "yarn.resourcemanager.store.class" : "org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore",
			        "yarn.resourcemanager.webapp.address" : "%HOSTGROUP::master2%:8088",
			        "yarn.resourcemanager.webapp.https.address" : "%HOSTGROUP::master2%:8090",
			        "yarn.timeline-service.address" : "%HOSTGROUP::master2%:10200",
			        "yarn.timeline-service.webapp.address" : "%HOSTGROUP::master2%:8188",
			        "yarn.timeline-service.webapp.https.address" : "%HOSTGROUP::master2%:8190"
				}}
		}],
		"host_groups": [
                        {"name": "master3",
                        "components": [
                                { "name": "ZOOKEEPER_SERVER" },
			        { "name": "METRICS_COLLECTOR" },
			        { "name": "METRICS_MONITOR" },
                                { "name": "HDFS_CLIENT" },
                                { "name": "YARN_CLIENT" },
                                { "name": "MAPREDUCE2_CLIENT" },
                                { "name": "ZOOKEEPER_CLIENT" },
				{ "name": "SPARK_JOBHISTORYSERVER" },
				{ "name": "KNOX_GATEWAY" },
				{ "name": "FALCON_SERVER" }],
                        "cardinality": 1 },
                        {"name": "bastion",
                        "components": [
                                { "name": "METRICS_MONITOR" },
                                { "name": "HDFS_CLIENT" },
                                { "name": "YARN_CLIENT" },
                                { "name": "MAPREDUCE2_CLIENT" },
                                { "name": "ZOOKEEPER_CLIENT" },
				{ "name": "OOZIE_CLIENT" },
				{ "name": "SPARK_CLIENT" },
				{ "name": "HBASE_CLIENT" },
				{ "name": "FALCON_CLIENT" },
				{ "name": "TEZ_CLIENT" },
				{ "name": "SQOOP" },
				{ "name": "HCAT" },
				{ "name": "PIG" }],
                        "cardinality": 1 },
			{"name": "master1",
			"components": [
				{ "name": "ZOOKEEPER_SERVER" },
				{ "name": "NAMENODE" },
				{ "name": "ZKFC" },
				{ "name": "JOURNALNODE" },
				{ "name": "RESOURCEMANAGER" },
				{ "name": "OOZIE_SERVER" },
                                { "name": "METRICS_MONITOR" }],
			"cardinality": 1 },
			{ "name": "master2",
			"components": [
				{ "name": "ZOOKEEPER_SERVER" },
				{ "name": "NAMENODE" },
				{ "name": "ZKFC" },
                                { "name": "JOURNALNODE" },
                                { "name": "METRICS_MONITOR" },
                                { "name": "RESOURCEMANAGER" },
                                { "name": "APP_TIMELINE_SERVER" },
                                { "name": "HISTORYSERVER" },
				{ "name": "HBASE_MASTER" },
				{ "name": "HIVE_METASTORE" },
				{ "name": "HIVE_SERVER" },
				{ "name": "MYSQL_SERVER" },
				{ "name": "PIG" },
				{ "name": "TEZ_CLIENT" },
				{ "name": "HDFS_CLIENT" },
				{ "name": "YARN_CLIENT" },
				{ "name": "MAPREDUCE2_CLIENT" },
				{ "name": "ZOOKEEPER_CLIENT" },
				{ "name": "WEBHCAT_SERVER" }],
			"cardinality": 1 },
			{ "name": "datanode",
			"components": [
				{ "name": "NODEMANAGER" },
                                { "name": "METRICS_MONITOR" },
				{ "name": "DATANODE" },
				{ "name": "HBASE_REGIONSERVER" },
				{ "name": "ZOOKEEPER_CLIENT"}]
			}
			],
		"Blueprints": {
			"blueprint_name": "${CLUSTER_NAME}",
			"stack_name": "HDP",
			"stack_version": "2.6",
			"security": { "type": "NONE" }
			}
		}
EOF
}

## Set HDP Repo
hdp_repo(){
cat << EOF
    {
    "Repositories" : {
       "repo_name" : "HDP Public Repo",
       "base_url" : "http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/${HDP_version}",
       "verify_base_url" : true
    }
    }
EOF
}

## Set Utils Repo
hdp_utils_repo(){
cat << EOF
    {
    "Repositories" : {
       "repo_name" : "HDP Utils Public Repo",
       "base_url" : "http://public-repo-1.hortonworks.com/HDP-UTILS-${UTILS_version}/repos/centos7",
       "verify_base_url" : true
    }
    }
EOF
}

## Config Execution wrapper
hdp_build_config(){
	create_hdfs_config
	create_cluster_config > cluster_config.json
	create_dynamic_hostmap > hostmap.json
	hdp_repo > repo.json
	hdp_utils_repo > hdputils-repo.json
}

## Submit Cluster Configuration Blueprint
hdp_register_cluster(){
	## Register BP with Ambari
	echo -e "\n-->Submitting cluster_config.json<--"
	curl -i -H "X-Requested-By: ambari" -X POST -u admin:admin http://${ambari_ip}:8080/api/v1/blueprints/${CLUSTER_NAME} -d @cluster_config.json
}

## Register HDP and Utils Repos
hdp_register_repo(){
	## Setup Repo using REST API
	echo -e "\n-->Submitting HDP and HDP Utils repo.json<--"
	curl -i -H "X-Requested-By: ambari" -X PUT -u admin:admin http://${ambari_ip}:8080/api/v1/stacks/HDP/versions/2.6/operating_systems/redhat7/repositories/HDP-2.6 -d @repo.json
	curl -i -H "X-Requested-By: ambari" -X PUT -u admin:admin http://${ambari_ip}:8080/api/v1/stacks/HDP/versions/2.6/operating_systems/redhat7/repositories/HDP-UTILS-${UTILS_version} -d @hdputils-repo.json
}

## Build the Cluster
hdp_cluster_build(){
	echo -e "\n-->Submitting hostmap.json (Cluster Build)<--"
	curl -i -H "X-Requested-By: ambari" -X POST -u admin:admin http://${ambari_ip}:8080/api/v1/clusters/${CLUSTER_NAME} -d @hostmap.json
}

##
## MAIN
##

## Pass Ambari Public IP - Ensure this is setup in the VCN
# Validate Ambari is up and listening
ambari_up=0
while [ $ambari_up = "0" ]; do 
	ambari_check=`(echo > /dev/tcp/${ambari_ip}/8080) >/dev/null 2>&1 && echo "UP" || echo "DOWN"`
	if [ $ambari_check = "UP" ]; then 
		echo -e "\n-> Ambari Server Found."
		ambari_up=1
		continue;
	else
		echo -ne "-> Ambari Server Not Detected... Retrying"
		sleep 5
	fi
done;

# Cluster Setup
echo -e "-> Building HDP Configuration"
hdp_build_config
sleep 3
echo -e "-> Registering HDP Cluster"
hdp_register_cluster
sleep 3
echo -e "-> Registering HDP Repository"
hdp_register_repo
sleep 3
echo -e "-> Building HDP $HDP_version Cluster $CLUSTER_NAME"
hdp_cluster_build
sleep 3
# Setup new admin account
echo -e "-> Creating new Admin account: ${ambari_login}"
new_admin > ${ambari_login}.json
curl -i -H "X-Requested-By: ambari" -X POST -u admin:admin -d @${ambari_login}.json http://${ambari_ip}:8080/api/v1/users
rm -f new_admin.json
sleep 3
# reset default  admin account to random password
echo -e "-> Reset default admin account to random password"
admin_password=`create_random_password`
admin_password_json > admin.json
curl -i -H "X-Requested-By: ambari" -X PUT -u admin:admin -d @admin.json http://${ambari_ip}:8080/api/v1/users
rm -f admin.json
echo -e "----------------------------------"
echo -e "-------- Cluster Building --------"
echo -e "--- Login to Ambari for Status ---"
echo -e "----------------------------------"
echo -e "Ambari Login: http://${ambari_ip}:8080"

