# hdp
This is a Terraform template for deploying a fully configured HDP cluster on OCI..

|             | Worker Nodes   | Bastion Instance | Utility and Master Instances |
|-------------|----------------|------------------|------------------------------|
| Recommended | BM.DenseIO2.52 | VM.Standard2.4   | VM.Standard2.16              |
| Minimum     | VM.Standard2.8 | VM.Standard2.1   | VM.Standard2.8               |

Host types can be customized in this template.   Also included with this template is an easy method to customize block volume quantity and size as pertains to HDFS capacity.   See "variables.tf" for more information in-line.

## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oracle/oci-quickstart-prerequisites).

## Scaling

Modify the [terraform/variables.tf](terraform/variables.tf) file prior to deployment and set the number of workers to scale your cluster dynamically.

	variable "worker_node_count" { default = "3" }

Alternatively, you can export this to your shell as a TF Variable:

	export TF_VAR_worker_node_count="5"

This would over-ride the default (minimum requirement) of 3 worker nodes and deploy 5 workers.   

## HDFS Storage Capacity - NVME & Block Volumes

By default this template is set to leverage DenseIO Bare Metal shapes with local NVME, as well as Block Volumes using Data Tiering for HDFS.   When mixed storage is provisioned, local NVME defaults to [DISK] and Block Volumes are set to [ARCHIVE] using the default Data Tiering storage policies.   If you change the worker type to a non-DenseIO shape, then you will need to scale the amount of HDFS capacity for the cluster by incrementing "hdfs_usable_in_gbs" variable.   This can be done in [terraform/variables.tf](terraform/variables.tf) or by exporting as a TF_VAR:

	export TF_VAR_hdfs_usable_in_gbs="10000"

This would set the usable HDFS Block Volume capacity to 10TB - Triple replication is accounted for in the formula used to setup Block Volumes so this would actually consume 30TB of Block Volume in the tenancy.  By default this value is set to "3000" (3TB).   All Block Volumes are set at 700GB in size with the variable "data_blocksize_in_gbs", it is not recommended to change this value below the default.  When scaling to Block Volume capacities beyond 22TB per worker, you will need to adjust the default blocksize to a larger value.  Failing to do so will result in attempting to request more Block Volume attachments than the instance can attach (32).

When using DenseIO local storage only, set this value to "0" to remove Block Volumes for HDFS entirely:

	export TF_VAR_hdfs_usable_in_gbs="0"

## Deployment Customization

Deployment customization is done by modifying a few files:
* [scripts/hdp_deploy.sh](scripts/hdp_deploy.sh) Cluster Deployment, customize Ambari admin credentials, HDP version, Cluster Name, Configuration and Cluster Topology.  Configuration and Topology customization requires knowledge of [Ambari Blueprints](https://cwiki.apache.org/confluence/display/AMBARI/Blueprints).  YAML can be modified/inserted into the appropriate section of this script to allow for custom deployment.
	
	HDP_version
	UTILS_version
	CLUSTER_NAME
	ambari_login
	ambari_password

* [scripts/boot.sh](scripts/boot.sh) CloudInit boot script for instances, customize HDP and Ambari Agent versions.
	
	ambari_version
	hdp_version	
	hdp_utils_version

* [scripts/boot_ambari.sh](scripts/boot_ambari.sh) CloudInit boot script for Ambari Utility server.  Customize HDP and Ambari versions. 
	
	ambari_version
	hdp_version
	hdp_utils_version

## Deployment

Deploy using standard Terraform commands

	terraform init
	terraform plan
	terraform apply

## Post Deployment

Terraform output will show a script command to deploy the cluster using Ambari Blueprints and Ambari API calls. This is done by building JSON files for host mapping and cluster topology, and submitting them to Ambari API using curl.  The entire process is automated and will give status output as it progresses through the deployment steps.

	../scripts/hdp_deploy.sh <ambari_server_ip> <availability_domain> <worker_shape> <hdfs_block_volumes_per_worker> <number_of_workers>

## Cluster Security

This template also includes Kerberos Secure Cluster installation by default.   This uses a local KDC on the Utility host.   Administration of Kerberos principals can be done on this host using "kadmin.local" as root user.   Principals are in the format of "<user>/<host_fqdn>@HADOOP.COM".  An admin principal for use with Ambari is also setup as part of deployment, "ambari/admin@HADOOP.COM".

When using secure cluster you should not over-write any of the default principals which are setup by Ambari.  For cluster administration it is suggested you set a principal for the HDFS user on the Utility host:

	kadmin.local
	add_principal hdfs/hw-utility-1.public3.hwvcn.oraclevcn.com

You will be prompted for a password for the principal.  Once complete, you can change to the HDFS user and authenticate using kinit:

	sudo su - hdfs
	kinit hdfs/`hostname -f`@HADOOP.COM

At this point HDFS administration can be done using normal hdfs dfs commands.

Kerberos can be customized to a custom realm if desired.   This will require modification of [scripts/boot.sh](scripts/boot.sh) and [scripts/boot_ambari.sh](scripts/boot_ambari.sh) for KDC server, and krb5 host configs.

It is also highly suggested you modify [scripts/boot_ambari.sh](scripts/boot_ambari.sh) and change the following default paramaters prior to Cluster deployment:

	KERBBEROS_PASSWORD="SOMEPASSWORD"
	AMBARI_USER_PASSWORD="somepassword"

## MySQL for Ambari and Metadata

MySQL Server is installed on the Ambari host for use with Ambari and Cluster Metadata.   The default database passwords are controlled in [scripts/boot_ambari.sh](scripts/boot_ambari.sh).  It is recommended to change these default values prior to deployment:

	mysql_db_password="somepassword"
	ambari_db_password="somepassword"

The "ambari_user" variable is the Database user for Ambari. 

## Destroy Deployment

To remove everything which was deployed using this template, you can use the standard terraform command:

	terraform destroy

This will prompt to ensure you wish to destroy everything, then will remove all elements of the deployment (effectively destroying all data in the process).  This is not recoverable. 
