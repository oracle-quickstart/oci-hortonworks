#!/bin/bash
## Ambari Setup Script

## Set some global variables first
#utilfqdn=`nslookup hw-master3-1 | grep Name | gawk '{print $2}'`
utilfqdn="hw-utility-1.public1.hwvcn.oraclevcn.com"
#master1fqdn=`nslookup hw-master-1 | grep Name | gawk '{print $2}'`
master1fqdn="hw-master-1.private1.hwvcn.oraclevcn.com"
#master2fqdn=`nslookup hw-master-2 | grep Name | gawk '{print $2}'`
master2fqdn="hw-master-2.private2.hwvcn.oraclevcn.com"
bastionfqdn="hw-bastion1.bastion1.hwvcn.oraclevcn.com"
## Ambari and HDP Version
ambari_version="2.6.2.0"
HDP_version="2.6.5.0"
UTILS_version="1.1.0.22"
## Cluster Info
CLUSTER_NAME="TestCluster"
ambari_login="admin"
ambari_password="somepassword"
##
## Functions
##

ambari_install () { 
wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/${ambari_version}/ambari.repo -O /etc/yum.repos.d/ambari.repo
yum install ambari-server -y
ambari-server setup -s
service ambari-server start
wget -nv http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.6.4.0/hdp.repo -O /etc/yum.repos.d/hdp.repo
wget -nv http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.22/repos/centos7/hdp-utils.repo -O /etc/yum.repos.d/hdp-utils.repo
}

## Detect and generate DFS config for HDFS
create_hdfs_config () { 
dc=0
while [ $dc -lt $hdfsdisks ]; do 
	if [ $dc = 0 ]; then
		dfs=`echo "\"/data${dc}/"`
	elif [ $dc = $((hdfsdisks-1)) ]; then 
		dfs=`echo "$dfs,/data${dc}/\""`
	else
	 	dfs=`echo "$dfs,/data${dc}/"`
	fi
	dc=$((dc+1))
done;
}

## Create Cluster hostmap.json
create_dynamic_hostmap () {
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
create_cluster_config () {
cat << EOF
{ 
	"configurations": [
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
                                { "name": "ZOOKEEPER_CLIENT" }],
                        "cardinality": 1 }, 
                        {"name": "bastion", 
                        "components": [
                                { "name": "METRICS_MONITOR" },
                                { "name": "HDFS_CLIENT" }, 
                                { "name": "YARN_CLIENT" }, 
                                { "name": "MAPREDUCE2_CLIENT" }, 
                                { "name": "ZOOKEEPER_CLIENT" }],
                        "cardinality": 1 },
			{"name": "master1", 
			"components": [
				{ "name": "ZOOKEEPER_SERVER" },
				{ "name": "NAMENODE" }, 
				{ "name": "ZKFC" },
				{ "name": "JOURNALNODE" },
				{ "name": "RESOURCEMANAGER" }, 
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
                                { "name": "HISTORYSERVER" }], 
			"cardinality": 1 }, 
			{ "name": "datanode", 
			"components": [
				{ "name": "NODEMANAGER" }, 
                                { "name": "METRICS_MONITOR" },
				{ "name": "DATANODE" }]
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
hdp_repo () {
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
hdp_utils_repo () { 
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
hdp_build_config () { 
	create_hdfs_config
	create_cluster_config > cluster_config.json
	create_dynamic_hostmap > hostmap.json
	hdp_repo > repo.json
	hdp_utils_repo > hdputils-repo.json
}

## Submit Cluster Configuration Blueprint
hdp_register_cluster () { 
	## Register BP with Ambari
	echo -e "\n-->Submitting cluster_config.json<--"
	curl -i -H "X-Requested-By: ambari" -X POST -u admin:admin http://${utilfqdn}:8080/api/v1/blueprints/${CLUSTER_NAME} -d @cluster_config.json
}

## Register HDP and Utils Repos
hdp_register_repo () {
	## Setup Repo using REST API
	echo -e "\n-->Submitting HDP and HDP Utils repo.json<--"
	curl -i -H "X-Requested-By: ambari" -X PUT -u admin:admin http://${utilfqdn}:8080/api/v1/stacks/HDP/versions/2.6/operating_systems/redhat7/repositories/HDP-2.6 -d @repo.json
	curl -i -H "X-Requested-By: ambari" -X PUT -u admin:admin http://${utilfqdn}:8080/api/v1/stacks/HDP/versions/2.6/operating_systems/redhat7/repositories/HDP-UTILS-${UTILS_version} -d @hdputils-repo.json
}

## Build the Cluster 
hdp_cluster_build () {
	echo -e "\n-->Submitting hostmap.json (Cluster Build)<--"
	curl -i -H "X-Requested-By: ambari" -X POST -u admin:admin http://${utilfqdn}:8080/api/v1/clusters/${CLUSTER_NAME} -d @hostmap.json
}

##
## MAIN
##
cd /home/opc/
wprocs=`cat /tmp/wprocs`
hdfsdisks=`cat /tmp/hdfsdisks`
wc=`cat hosts | grep worker | wc -l`
ambari_install
hdp_build_config
hdp_register_cluster
hdp_register_repo
hdp_cluster_build
echo -e "----------------------------------"
echo -e "-------- Cluster Building --------"
echo -e "--- Login to Ambari for Status ---"
echo -e "----------------------------------"
