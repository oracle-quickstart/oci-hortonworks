#!/bin/bash
# Ambari Setup Script to deploy HDF

# Parameters are passed to script

## Util FQDN is the Public IP of the Ambari host
ambari_ip=$1
## AD is needed to set proper subnet for host topology
ad=$2
## Master Node count
master_count=$3
## Master Node Shape
master_shape=$4

if [ -z $4 ]; then
	echo "Usage:\n"
	echo "./hdf_install.sh <ambari_public_ip> <availability_domain> <master_node_count> <master_node_shape>"
	exit
fi

# Set some Global Variables first

## Ambari and HDP Version
ambari_version="2.6.2.2"
hdf_version="3.1.0.0"

## Cluster Info 
CLUSTER_NAME="HDFTestCluster"
## Set a new admin account and password
ambari_login="hdfadmin"
ambari_password="somepassword"
db_password="somepassword"
nifi_password="somepassword"

## Host Mapping needed for cluster config
utilfqdn="hw-utility-1.public${ad}.hwvcn.oraclevcn.com"
master1fqdn="hw-master-1.private${ad}.hwvcn.oraclevcn.com"
master2fqdn="hw-master-2.private${ad}.hwvcn.oraclevcn.com"
bastionfqdn="hw-bastion.bastion${ad}.hwvcn.oraclevcn.com"

# End Global Variables

case $master_shape in
        BM.Standard.E2.64)
        wprocs=64
        ;;

        BM.DenseIO2.52|BM.Standard2.52|BM.GPU3.8)
	wprocs=52
        ;;

        BM.HPC2.36|BM.DenseIO1.36|BM.Standard1.36)
        wprocs=36
        ;;

        BM.GPU2.2)
        wprocs=28
        ;;

        VM.DenseIO2.24|VM.Standard2.24|VM.GPU3.4)
        wprocs=24
        ;;

        VM.DenseIO2.16|VM.DenseIO1.16|VM.Standard2.16|VM.Standard1.16)
        wprocs=16
        ;;

        VM.GPU2.1|VM.GPU3.2)
        wprocs=12
        ;;

        VM.DenseIO2.8|VM.DenseIO1.8|VM.Standard2.8|VM.Standard1.8|VM.StandardE2.8)
        wprocs=8
        ;;

        VM.GPU3.1)
        wprocs=6
        ;;

        *)
        echo "Unsupported Master Shape ${master_shape} - validate this is a supported OCI shape for use as a Master Node."
        exit
        ;;

esac
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

# Create Cluster hostmap.json
create_dynamic_hostmap(){
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
            "host_count": "$((master_count-3))",
            "host_predicate": "Hosts/cpu_count=$((wprocs*2))"
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

# Create Cluster configuration cluster_config.json
# Modify this section carefully to apply custom cluster configuration at build time
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
        curl -i -s -k -H "X-Requested-By: ambari" -X POST -u admin:admin https://${ambari_ip}:9443/api/v1/blueprints/${CLUSTER_NAME} -d @cluster_config.json >> hdf_deploy_output.log
}

## Register HDP and Utils Repos
hdf_register_repo () {
        ## Setup Repo using REST API
        echo -e "\n-->Submitting HDF repo.json<--"
        curl -i -s -k -H "X-Requested-By: ambari" -X PUT -u admin:admin https://${ambari_ip}:9443/api/v1/stacks/HDF/versions/3.1/operating_systems/redhat7/repositories/HDF-3.1 -d @repo.json >> hdf_deploy_output.log
}

## Build the Cluster 
hdf_cluster_build () {
        echo -e "\n-->Submitting hostmap.json (HDF Cluster Build)<--"
        curl -i -s -k -H "X-Requested-By: ambari" -X POST -u admin:admin https://${ambari_ip}:9443/api/v1/clusters/${CLUSTER_NAME} -d @hostmap.json >> hdf_deploy_output.log
}

ssl_setup () {
        nc=1
	host_count=$((master_count+1))
	mc=1
        while [ $nc -le $host_count ]; do
                if [ -z "${ssl_data}" ]; then
                        ssl_data="<property name='Node Identity ${nc}'>CN=${utilfqdn}, OU=HORTONWORKS</property>"
		elif [ $nc = 2 ]; then 
			ssl_data="${ssl_data}<property name='Node Identity ${nc}'>CN=${bastionfqdn}, OU=HORTONWORKS</property>"
                else
                        ssl_data="${ssl_data}<property name='Node Identity ${nc}'>CN=hw-master-${mc}.private${ad}.hwvcn.oraclevcn.com, OU=HORTONWORKS</property>"
			mc=$((mc+1))
                fi
                nc=$((nc+1))
        done;
}

# Check Ambari Requests - wait until finished
check_ambari_requests(){
	sleep 5
	completed_requests="0"
	echo -e "Checking Ambari requests..."
	total_requests=`curl -k -i -s -H "X-Requested-By: ambari" -u ${ambari_login}:${ambari_password} -X GET https://${ambari_ip}:9443/api/v1/clusters/${CLUSTER_NAME}/requests?fields=Requests/id,Requests/request_status,Requests/request_context | grep -e '"request_status"' | wc -l`
	echo -e "$total_requests requests found."
	if [ $total_requests = "0" ]; then
	        echo -e "Failed to find requests... check Ambari manually for cluster status, check hdf_deplooy_output.log for more detail."
	        echo -e "Ambari Login: https://${ambari_ip}:9443"
	        exit
	fi
	req_start=`date +%H:%M:%S`
	while [ $completed_requests != $total_requests ]; do
        	completed_requests=`curl -k -i -s -H "X-Requested-By: ambari" -u ${ambari_login}:${ambari_password} -X GET https://${ambari_ip}:9443/api/v1/clusters/${CLUSTER_NAME}/requests?fields=Requests/id,Requests/request_status,Requests/request_context | grep -e '"request_status"' | grep "COMPLETED" | wc -l`
	        pending_requests=`curl -k -i -s -H "X-Requested-By: ambari" -u ${ambari_login}:${ambari_password} -X GET https://${ambari_ip}:9443/api/v1/clusters/${CLUSTER_NAME}/requests?fields=Requests/id,Requests/request_status,Requests/request_context | grep -e '"request_status"' | grep "PENDING" | wc -l`
	        in_progress_requests=`curl -k -i -s -H "X-Requested-By: ambari" -u ${ambari_login}:${ambari_password} -X GET https://${ambari_ip}:9443/api/v1/clusters/${CLUSTER_NAME}/requests?fields=Requests/id,Requests/request_status,Requests/request_context | grep -e '"request_status"' | grep "IN_PROGRESS" | wc -l`
	        total_requests=`curl -k -i -s -H "X-Requested-By: ambari" -u ${ambari_login}:${ambari_password} -X GET https://${ambari_ip}:9443/api/v1/clusters/${CLUSTER_NAME}/requests?fields=Requests/id,Requests/request_status,Requests/request_context | grep -e '"request_status"' | wc -l`
		req_now=`date +%H:%M:%S`
		req_now_s=`date +%s -d ${req_now}`
		req_start_s=`date +%s -d ${req_start}`
		req_diff=`expr ${req_now_s} - ${req_start_s}`	
	        echo -ne " [`date +%H:%M:%S -ud @${req_diff}`] Cluster Action Status: $pending_requests pending, $in_progress_requests in progress, ${completed_requests}/${total_requests} complete.\r"
	    	sleep 5
		
		
	done;
	echo -e "\n->Action Complete."
}

# Build Kerberos Service Payload
build_kerberos_payload(){
cat << EOF
[
  {
    "Clusters": {
      "desired_config": {
        "type": "krb5-conf",
        "tag": "version1",
        "properties": {
          "domains":"",
          "manage_krb5_conf": "false",
          "conf_dir":"/etc",
	  "content" : " "
        }
      }
    }
  },
  {
    "Clusters": {
      "desired_config": {
        "type": "kerberos-env",
        "tag": "version1",
        "properties": {
          "kdc_type": "mit-kdc",
          "manage_identities": "true",
          "install_packages": "true",
          "encryption_types": "rc4-hmac",
          "realm" : "HADOOP.COM",
          "kdc_hosts" : "${utilfqdn}",
          "kdc_host" : "${utilfqdn}",
          "admin_server_host" : "${utilfqdn}",
          "executable_search_paths" : "/usr/bin, /usr/kerberos/bin, /usr/sbin, /usr/lib/mit/bin, /usr/lib/mit/sbin",
          "password_length": "20",
          "password_min_lowercase_letters": "1",
          "password_min_uppercase_letters": "1",
          "password_min_digits": "1",
          "password_min_punctuation": "1",
          "password_min_whitespace": "0",
          "service_check_principal_name" : "${CLUSTER_NAME}-service_check",
          "case_insensitive_username_rules" : "false"
        }
      }
    }
  }
]
EOF
}

# Build KDC Admin Credential Payload
build_kdc_payload(){
cat << EOF
{
  "session_attributes" : {
    "kerberos_admin" : {
      "principal" : "ambari/admin@HADOOP.COM",
      "password" : "somepassword"
    }
  },
  "Clusters": {
    "security_type" : "KERBEROS"
  }
}
EOF
}

# Enable Kerberos
enable_kerberos(){
	echo -e "-->Adding KERBEROS Service to cluster"
	echo -e "-->Adding KERBEROS Service to cluster" >> hdf_deploy_output.log
	curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X POST https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME/services/KERBEROS >> hdf_deploy_output.log
	echo -e "-->Adding KERBEROS_CLIENT component to the KERBEROS service"
	echo -e "-->Adding KERBEROS_CLIENT component to the KERBEROS service" >> hdf_deploy_output.log
	sleep 1
	curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X POST https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME/services/KERBEROS/components/KERBEROS_CLIENT >> hdf_deploy_output.log
	sleep 1
	build_kerberos_payload > kpayload.json
	echo -e "-->Submitting KERBEROS Payload"
	echo -e "-->Submitting KERBEROS Payload" >> hdf_deploy_output.log
	curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X PUT -d @kpayload.json https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME >> hdf_deploy_output.log
	echo -e "-->Creating the KERBEROS_CLIENT host components for each cluster host"
	for cluster_host in `curl -s -k -u ${ambari_login}:${ambari_password} -H "X-Requested-By: ambari" -X GET https://${ambari_ip}:9443/api/v1/clusters/${CLUSTER_NAME}/hosts | grep host_name | gawk '{print $3}' | cut -d '"' -f2`;
	do
		echo -e "--->Adding ${cluster_host}"
		echo -e "--->Adding ${cluster_host}" >> hdf_deploy_output.log
	        curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X POST -d '{"host_components" : [{"HostRoles" : {"component_name":"KERBEROS_CLIENT"}}]}' https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME/hosts?Hosts/host_name=${cluster_host} >> hdf_deploy_output.log
	        sleep 1
	done
	echo -e "-->Installing KERBEROS Cluster Service and Components"
	echo -e "-->Installing KERBEROS Cluster Service and Components" >> hdf_deploy_output.log
	curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X PUT -d '{"RequestInfo": {"context" :"Install Kerberos Cluster Service"}, "Body": {"ServiceInfo": {"state" : "INSTALLED"}}}' https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME/services/KERBEROS >> hdf_deploy_output.log
	check_ambari_requests
	echo -e "-->Stopping all Cluster services"
	echo -e "-->Stopping all Cluster services" >> hdf_deploy_output.log
	curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X PUT -d '{"RequestInfo": {"context" :"Stop Cluster Services"}, "Body": {"ServiceInfo": {"state" : "INSTALLED"}}}' https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME/services >> hdf_deploy_output.log
	check_ambari_requests
	#if [[ "${AMBARI_VERSION:0:3}" > "2.7" ]] || [[ "${AMBARI_VERSION:0:3}" == "2.7" ]]; then
	#       echo -e "\n`ts` Uploading Kerberos Credentials"
	#        curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X POST -d '{ "Credential" : { "principal" : "admin/admin@'$REALM'", "key" : "hadoop", "type" : "temporary" }}' https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME/credentials/kdc.admin.credential
	#        sleep 1
	#fi
	echo -e "-->Enabling Kerberos"
	echo -e "-->Enabling Kerberos" >> hdf_deploy_output.log
	build_kdc_payload > payload.json
	curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X PUT -d @payload.json https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME >> hdf_deploy_output.log
	check_ambari_requests
	echo -e "->Starting Cluster Services"
	echo -e "->Starting Cluster Services" >> hdf_deploy_output.log
	curl -i -s -k -H "X-Requested-By:ambari" -u ${ambari_login}:${ambari_password} -i -X PUT -d '{"RequestInfo": {"context" :"Start Cluster Services"}, "Body": {"ServiceInfo": {"state" : "STARTED"}}}' https://${ambari_ip}:9443/api/v1/clusters/$CLUSTER_NAME/services>> hdf_deploy_output.log
	check_ambari_requests
}

##
## MAIN
##

## Pass Ambari Public IP - Ensure this is setup in the VCN
# Validate Ambari is up and listening
ambari_up=0
while [ $ambari_up = "0" ]; do 
	ambari_check=`(echo > /dev/tcp/${ambari_ip}/9443) >/dev/null 2>&1 && echo "UP" || echo "DOWN"`
	if [ $ambari_check = "UP" ]; then 
		echo -e "\n-> Ambari Server Found."
		ambari_up=1
		continue;
	else
		echo -ne "-> Ambari Server Not Detected... Retrying\r"
		sleep 5
	fi
done;
start_time=`date +%Y-%m%d-%H:%M:%S`
start_time_s=`date +%H:%M:%S`
echo -e "$start_time" > hdf_deploy_output.log
# Cluster Setup
ssl_setup
echo -e "-> Building HDF Configuration"
hdf_build_config
sleep 3
echo -e "-> Registering HDF Cluster"
hdf_register_cluster
sleep 3
echo -e "-> Registering HDF Repository"
hdf_register_repo
sleep 3
echo -e "-> Building HDF $hdf_version Cluster $CLUSTER_NAME"
hdf_cluster_build
sleep 3
# Setup new admin account
echo -e "-> Creating new Admin account: ${ambari_login}"
new_admin > ${ambari_login}.json
curl -i -s -k -H "X-Requested-By: ambari" -X POST -u admin:admin -d @${ambari_login}.json https://${ambari_ip}:9443/api/v1/users >> hdf_deploy_output.log
rm -f new_admin.json
sleep 3
# reset default  admin account to random password
echo -e "-> Reset default admin account to random password"
admin_password=`create_random_password`
admin_password_json > admin.json
curl -i -s -k -H "X-Requested-By: ambari" -X PUT -u admin:admin -d @admin.json https://${ambari_ip}:9443/api/v1/users >> hdf_deploy_output.log
rm -f admin.json
check_ambari_requests
enable_kerberos
end_time=`date +%Y-%m%d-%H:%M:%S`
end_time_s=`date +%H:%M:%S` 
echo -e "\t--CLUSTER SETUP COMPLETE--"
echo -e "\t--SUMMARY--"
total1=`date +%s -d ${start_time_s}`
total2=`date +%s -d ${end_time_s}`
totaldiff=`expr ${total2} - ${total1}`
echo -e "\tCluster Setup Took `date +%H:%M:%S -ud @${totaldiff}`"
echo -e "----------------------------------"
echo -e "Ambari Login: https://${ambari_ip}:9443"

