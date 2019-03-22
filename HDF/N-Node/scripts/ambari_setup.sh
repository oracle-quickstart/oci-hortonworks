#!/bin/bash
## Ambari Setup Script

## Set some global variables first
utilfqdn=`nslookup hdf-utility-1 | grep Name | gawk '{print $2}'`
master1fqdn=`nslookup hdf-master-1 | grep Name | gawk '{print $2}'`
master2fqdn=`nslookup hdf-master-2 | grep Name | gawk '{print $2}'`
bastionfqdn=`nslookup hdf-bastion1 | grep Name | gawk '{print $2}'`
## Ambari and HDP Version
ambari_version="2.6.1.0"
hdf_version="3.1.0.0"
## Cluster Info
CLUSTER_NAME="HDFTestCluster"
ambari_login="admin"
ambari_password="somepassword"
## MySQL Password
db_password="StrongPassword"
## NIFI Password
nifi_password="StrongPassword"   
##
## Functions
##

gen_mysql () {
cat << EOF 
ALTER USER 'root'@'localhost' IDENTIFIED BY 'Secur1ty!';
uninstall plugin validate_password;
CREATE DATABASE registry DEFAULT CHARACTER SET utf8; CREATE DATABASE streamline DEFAULT CHARACTER SET utf8;
CREATE USER 'registry'@'%' IDENTIFIED BY '${db_password}'; CREATE USER 'streamline'@'%' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON registry.* TO 'registry'@'%' WITH GRANT OPTION ; GRANT ALL PRIVILEGES ON streamline.* TO 'streamline'@'%' WITH GRANT OPTION ;
commit;
EOF
}

ambari_install () { 
export ambari_login=${ambari_login}
export ambari_password=${ambari_password}
export db_password=${db_password}
export nifi_password=${nifi_password}
export cluster_name=${CLUSTER_NAME}
export ambari_services="ZOOKEEPER STREAMLINE NIFI KAFKA STORM REGISTRY NIFI_REGISTRY AMBARI_METRICS" 
## THIS VERSION IS HARD CODED - NEED TO FIX
export hdf_ambari_mpack_url="http://public-repo-1.hortonworks.com/HDF/centos7/3.x/updates/3.1.0.0/tars/hdf_ambari_mp/hdf-ambari-mpack-3.1.0.0-564.tar.gz"
## Pre
wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/${ambari_version}/ambari.repo -O /etc/yum.repos.d/ambari.repo
yum install ambari-server -y
ambari-server setup -s
service ambari-server start
wget -nv http://public-repo-1.hortonworks.com/HDF/centos7/3.x/updates/${hdf_version}/hdf.repo -O /etc/yum.repos.d/hdf.repo
##
yum localinstall -y https://dev.mysql.com/get/mysql57-community-release-el7-8.noarch.rpm
yum install -y epel-release mysql-connector-java* mysql-community-server
# MySQL Setup to keep the new services separate from the originals
echo Database setup...
systemctl enable mysqld.service
systemctl start mysqld.service
#extract system generated Mysql password
oldpass=$( grep 'temporary.*root@localhost' /var/log/mysqld.log | tail -n 1 | sed 's/.*root@localhost: //' )
#create sql file that
# 1. reset Mysql password to temp value and create druid/superset/registry/streamline schemas and users
# 2. sets passwords for druid/superset/registry/streamline users to ${db_password}
gen_mysql > mysql-setup.sql
#execute sql file
mysql -h localhost -u root -p"$oldpass" --connect-expired-password < mysql-setup.sql
#change Mysql password to DB Password
mysqladmin -u root -p'Secur1ty!' password ${db_password}
#test password and confirm dbs created
mysql -u root -p${db_password} -e 'show databases;'
ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar
ambari-server install-mpack --mpack=${hdf_ambari_mpack_url} --verbose
service ambari-server restart
}

## Create Cluster hostmap.json
create_dynamic_hostmap () {
cat << EOF   
{
        "blueprint": "${CLUSTER_NAME}",
        "default_password": "hadoop",
        "host_groups": [{
            "name": "utility",
            "hosts": [{ "fqdn": "${utilfqdn}" }]
        }, {
            "name": "master1",
            "hosts": [{ "fqdn": "${master1fqdn}" }]
        }, {
            "name": "master2",
            "hosts": [{ "fqdn": "${master2fqdn}" }]
        }, {
	    "name": "master3",
	    "host_count": "${wc}",
	    "host_predicate": "Hosts/cpu_count>4"
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
	        { "ams-hbase-env": {
        	        "properties": {
                	        "hbase_master_heapsize": "512",
                        	"hbase_regionserver_heapsize": "768",
	                        "hbase_master_xmn_size": "192"
	                }}
	        },
        	{ "storm-site": {
                	"properties": {
	                        "metrics.reporter.register": "org.apache.hadoop.metrics2.sink.storm.StormTimelineMetricsReporter"
	                }}
	        },
        	{ "ams-hbase-site": {
	                "properties": {
	                        "hbase.regionserver.global.memstore.upperLimit": "0.35",
	                        "hbase.regionserver.global.memstore.lowerLimit": "0.3",
	                        "hbase.tmp.dir": "/var/lib/ambari-metrics-collector/hbase-tmp",
	                        "hbase.hregion.memstore.flush.size": "134217728",
	                        "hfile.block.cache.size": "0.3",
	                        "hbase.rootdir": "file:///var/lib/ambari-metrics-collector/hbase",
	                        "hbase.cluster.distributed": "false",
	                        "phoenix.coprocessor.maxMetaDataCacheSize": "20480000",
	                        "hbase.zookeeper.property.clientPort": "61181"
        	  }}
	        },
        	{ "logsearch-properties": {} },
	        { "kafka-log4j": {} },
	        { "kafka-broker": {
	                "properties": {
	                        "kafka.metrics.reporters": "org.apache.hadoop.metrics2.sink.kafka.KafkaTimelineMetricsReporter"
	          }}
	        },
	        { "ams-grafana-env": {
			"properties": {
				"metrics_grafana_password": "${db_password}"
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
		{ "nifi-ambari-config": {
			"properties" : {
			        "nifi.security.encrypt.configuration.password": "${nifi_password}",
			        "nifi.content.repository.dir.default": "/nifi/content_repository",
			        "nifi.database.dir": "/nifi/database_repository",
			        "nifi.flowfile.repository.dir": "/nifi/flowfile_repository",
			        "nifi.internal.dir": "/nifi",
			        "nifi.provenance.repository.dir.default": "/nifi/provenance_repository",        
			        "nifi.max_mem": "4g",        
			        "nifi.node.port": "9092",                
			        "nifi.node.protocol.port": "9089",                        
			        "nifi.node.ssl.port": "9093"                                
			},
			"nifi-env": {
			        "nifi_user": "nifi",
			        "nifi_group": "nifi"
    			}}
		},
		{ "nifi-ambari-ssl-config": {
			"properties" : {
			        "nifi.toolkit.tls.token": "hadoop",
			        "nifi.node.ssl.isenabled": "true",
			        "nifi.security.needClientAuth": "true",
			        "nifi.toolkit.dn.suffix": ", OU=HORTONWORKS",
			        "nifi.initial.admin.identity": "CN=nifiadmin, OU=HORTONWORKS",
				"content": "$ssl_data"
    			}}
		},
		{ "nifi-registry-ambari-config": {
			"properties": {
				"nifi.registry.security.encrypt.configuration.password": "${nifi_password}"
			}}
		},
		{ "registry-common": {
			"properties": {
				"jar.storage.type": "local",
				"registry.storage.connector.connectURI": "jdbc:mysql://${utilfqdn}:3306/registry",
				"registry.storage.type": "mysql",
				"registry.storage.connector.password": "${db_password}"
			}}
		},
    		{ "streamline-common": {
			"properties": {
				"jar.storage.type": "local",
				"streamline.storage.type": "mysql",
				"streamline.storage.connector.connectURI": "jdbc:mysql://${utilfqdn}:3306/streamline",
				"registry.url" : "http://localhost:7788/api/v1",
				"streamline.dashboard.url" : "http://localhost:9089",
				"streamline.storage.connector.password": "${db_password}"
			}}
		}], 
	"host_groups": [
        	{ "name": "utility", 
                        "components": [
				{ "name": "DRPC_SERVER" },
                                { "name": "INFRA_SOLR" },
                                { "name": "INFRA_SOLR_CLIENT" },
				{ "name": "KAFKA_BROKER" },
                                { "name": "LOGSEARCH_LOGFEEDER" },
                                { "name": "LOGSEARCH_SERVER" }, 
				{ "name": "METRICS_COLLECTOR" },
			        { "name": "METRICS_MONITOR" },
			        { "name": "METRICS_GRAFANA" },
			        { "name": "NIFI_CA" },
				{ "name": "NIFI_MASTER" },
				{ "name": "NIFI_REGISTRY_MASTER" },
				{ "name": "NIMBUS" },
				{ "name": "RANGER_ADMIN" },
				{ "name": "RANGER_USERSYNC" },
				{ "name": "REGISTRY_SERVER" },
                                { "name": "STREAMLINE_SERVER" },
                                { "name": "STORM_UI_SERVER" },
                                { "name": "SUPERVISOR" },
				{ "name": "ZOOKEEPER_CLIENT" },
				{ "name": "ZOOKEEPER_SERVER" }],
                        "cardinality": 1 }, 
                { "name": "bastion", 
                        "components": [
				{ "name": "LOGSEARCH_LOGFEEDER" },
                                { "name": "METRICS_MONITOR" },
                                { "name": "ZOOKEEPER_CLIENT" }],
                        "cardinality": 1 },
		{ "name": "master1", 
			"components": [
                                { "name": "INFRA_SOLR" },
                                { "name": "INFRA_SOLR_CLIENT" },
                                { "name": "KAFKA_BROKER" }, 
                                { "name": "METRICS_MONITOR" },
                                { "name": "SUPERVISOR" },
                                { "name": "LOGSEARCH_LOGFEEDER" },
                                { "name": "ZOOKEEPER_CLIENT" },
                                { "name": "ZOOKEEPER_SERVER" }],				
			"cardinality": 1 }, 
		{ "name": "master2", 
			"components": [
				{ "name": "INFRA_SOLR" },
				{ "name": "INFRA_SOLR_CLIENT" },
				{ "name": "KAFKA_BROKER" }, 
				{ "name": "METRICS_MONITOR" },
				{ "name": "SUPERVISOR" },
				{ "name": "LOGSEARCH_LOGFEEDER" },
				{ "name": "ZOOKEEPER_CLIENT" },
				{ "name": "ZOOKEEPER_SERVER" }],
			"cardinality": 1 }, 
		{ "name": "master3", 
                        "components": [
				{ "name": "INFRA_SOLR_CLIENT" },
                                { "name": "LOGSEARCH_LOGFEEDER" },				
				{ "name": "METRICS_MONITOR" }, 
				{ "name": "RANGER_ADMIN" },
				{ "name": "SUPERVISOR" },
                                { "name": "ZOOKEEPER_CLIENT" }]
                        } 
			], 
	"Blueprints": { 
			"blueprint_name": "${CLUSTER_NAME}", 
			"stack_name": "HDF", 
			"stack_version": "3.1"
			} 
		} 
EOF
}


## Set HDP Repo
hdf_repo () {
cat << EOF
    {
    "Repositories" : {
       "repo_name" : "HDF Public Repo",
       "base_url" : "http://public-repo-1.hortonworks.com/HDF/centos7/3.x/updates/${hdf_version}",
       "verify_base_url" : true
    }
    }
EOF
}

## Config Execution wrapper
hdf_build_config () { 
	create_cluster_config > cluster_config.json
	create_dynamic_hostmap > hostmap.json
	hdf_repo > repo.json
}

## Submit Cluster Configuration Blueprint
hdf_register_cluster () { 
	## Register BP with Ambari
	echo -e "\n-->Submitting cluster_config.json<--"
	curl -i -H "X-Requested-By: ambari" -X POST -u admin:admin http://${utilfqdn}:8080/api/v1/blueprints/${CLUSTER_NAME} -d @cluster_config.json
}

## Register HDP and Utils Repos
hdf_register_repo () {
	## Setup Repo using REST API
	echo -e "\n-->Submitting HDF repo.json<--"
	curl -i -H "X-Requested-By: ambari" -X PUT -u admin:admin http://${utilfqdn}:8080/api/v1/stacks/HDF/versions/3.1/operating_systems/redhat7/repositories/HDF-3.1 -d @repo.json
}

## Build the Cluster 
hdf_cluster_build () {
	echo -e "\n-->Submitting hostmap.json (HDF Cluster Build)<--"
	curl -i -H "X-Requested-By: ambari" -X POST -u admin:admin http://${utilfqdn}:8080/api/v1/clusters/${CLUSTER_NAME} -d @hostmap.json
}

host_count () { 
	if [ -f hosts ]; then 
		wc=`cat hosts | grep hdf-master | grep -iv hdf-master-1 | grep -iv hdf-master-2 | wc -l`
	else
		wc="0"
	fi
}

ssl_setup () {
	nc=1
	for host in `cat hosts | gawk '{print $2}'`; do 
		if [ -z "${ssl_data}" ]; then 
			ssl_data="<property name='Node Identity ${nc}'>CN=${host}, OU=HORTONWORKS</property>"
		else
			ssl_data="${ssl_data}<property name='Node Identity ${nc}'>CN=${host}, OU=HORTONWORKS</property>"
		fi
		nc=$((nc+1))
	done;
}
##
## MAIN
##
cd /home/opc/
host_count
ssl_setup
ambari_install
hdf_build_config
hdf_register_cluster
hdf_register_repo
hdf_cluster_build
echo -e "----------------------------------"
echo -e "-------- Cluster Building --------"
echo -e "--- Login to Ambari for Status ---"
echo -e "----------------------------------"
