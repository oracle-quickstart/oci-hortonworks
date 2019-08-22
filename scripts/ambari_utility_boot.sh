#!/bin/bash
LOG_FILE="/var/log/hortonworks-OCI-initialize.log"
log() { 
	echo "$(date) [${EXECNAME}]: $*" >> "${LOG_FILE}" 
}
EXECNAME="Metadata Extraction"
log "->Deployment Script Decode"
curl -L http://169.254.169.254/opc/v1/instance/metadata/hdp_deploy | base64 -d > /var/lib/cloud/instance/scripts/hdp_deploy.sh.gz
log "-->Extract"
gunzip /var/lib/cloud/instance/scripts/hdp_deploy.sh.gz >> $LOG_FILE
log "->Ambari Setup Script Decode"
curl -L http://169.254.169.254/opc/v1/instance/metadata/ambari_setup | base64 -d > /var/lib/cloud/instance/scripts/ambari_setup.sh.gz
log"-->Extract"
gunzip /var/lib/cloud/instance/scripts/ambari_setup.sh.gz
chmod +x /var/lib/cloud/instance/scripts/ambari_setup.sh
chmod +x /var/lib/cloud/instance/scripts/hdp_deploy.sh
EXECNAME="Ambari Setup"
log "->Execute"
cd /var/lib/cloud/instance/scripts/
./ambari_setup.sh
EXECNAME="HDP Deplyment"
log "->Execute - check /var/log/hdp-OCI-deploy.log for build debug"
./hdp_deploy.sh
