# oci-hortonworks
These are Terraform modules that deploy [Hortonworks](https://hortonworks.com/products/) on [Oracle Cloud Infrastructure (OCI)](https://cloud.oracle.com/en_US/cloud-infrastructure).  They are developed jointly by Oracle and Cloudera.

|                       | Worker Nodes   | Bastion Instance | Utility and Master Instances |
|-----------------------|----------------|------------------|------------------------------|
| Recommended (Default) | BM.DenseIO2.52 | VM.Standard2.4   | VM.Standard2.16              |
| Minimum               | VM.Standard2.8 | VM.Standard2.1   | VM.Standard2.8               |

Host types can be customized in this template.   Also included with this template is an easy method to customize block volume quantity and size as pertains to HDFS capacity.   See "variables.tf" for more information in-line.

## Scaling

Modify the variable "worker_node_count" to scale the number of cluster workers.   The default (minimum) is 3 nodes.

	variable "worker_node_count" { default = "3" }

## HDFS Storage Capacity - NVME & Block Volumes

By default this template is set to leverage DenseIO Bare Metal shapes with local NVME, as well as Block Volumes using Data Tiering for HDFS.   When mixed storage is provisioned, local NVME defaults to [DISK] and Block Volumes are set to [ARCHIVE] using the default Data Tiering storage policies.   If you change the worker type to a non-DenseIO shape, then you will need to scale the amount of HDFS capacity for the cluster by incrementing the "block_volumes_per_worker" variable.   By default these volumes are 700GB in size, which maximizes IOPS and throughput at a per-volume level.

When using DenseIO local storage only, set "block_volumes_per_worker" to "0" to remove Block Volumes for HDFS entirely and only use local NVME for HDFS.

If higher density is required, the block volume size can be scaled up in tandem with the block volume count using the variable "data_blocksize_in_gbs".  Best practice is to scale wider on the number of block volumes per worker rather than using a small number of high capacity volumes.

## Block Volumes for Logs & Cache
This deployment also sets up a 4-volume RAID0 partition using 700GB Block Volumes mounted to Workers as /hadoop.   This facilitates a 2TB caching layer for log data and other data in transit as part of workload.    The /tmp file system is also bond mounted to this location, to provide a fast caching layer as well as prevent the OS filesystem from being consumed entirely.

## Deployment Customization

Version 3.x versus 2.x deployment is controlled using the following variables:

	hdp_version
	ambari_version

Refer to the [Hortonworks Support Matrix](https://supportmatrix.hortonworks.com/) for version dependencies between platform components.

The variable "deployment_type" controls whether Secure Cluster is setup as part of deployment.   By default this template is set to use "simple" deployment, which is a fast deployment.  To enable Kerberos for cluster security, change the "deployment_type" to "secure".   This setup takes a little longer, see the Cluster Security section below for more detail.

Additional Deployment customization is done by modifying a few files:
* [scripts/hdp_deploy.sh](scripts/hdp_deploy.sh) Cluster Deployment, customize Ambari admin credentials, HDP version, Cluster Name, Configuration and Cluster Topology.  Configuration and Topology customization requires knowledge of [Ambari Blueprints](https://cwiki.apache.org/confluence/display/AMBARI/Blueprints).  YAML can be modified/inserted into the appropriate section of this script to allow for custom deployment.
	
	UTILS_version
	CLUSTER_NAME
	ambari_login
	ambari_password

## Deployment

Deployment uses [OCI Resource Manager](https://docs.cloud.oracle.com/iaas/Content/ResourceManager/Concepts/resourcemanager.htm).  Step by step instructions can be found [here](https://blogs.oracle.com/cloud-infrastructure/deploy-hadoop-easily-on-oracle-cloud-infrastructure-using-resource-manager).

* Create a Stack in Resource Manager
* Upload a [zipball](https://github.com/oracle/oci-quickstart-hortonworks/zipball/resource-manager) of this branch
* Copy the contents of a public/private SSH keypair to the variables section
* Alternatively modify any deployment variables (such as worker_shape)
* Run a Plan action in Resource Manager
* Run an Apply action in Resource Manager

Log output will show the Ambari IP address once Apply is finished.  Note that this URL will be available several minutes after the action is finished, as installation and deployment is done using CloudInit.

## Cluster Security

This template also includes Kerberos Secure Cluster installation as an option.  Setting "deployment_type" to "secure" will enable Kerberos.  This uses a local KDC on the Utility host.   Administration of Kerberos principals can be done on this host using "kadmin.local" as root user.   Principals are in the format of "user/<host_fqdn>@HADOOP.COM".  An admin principal for use with Ambari is also setup as part of deployment, "ambari/admin@HADOOP.COM".

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

* Run a Destroy action from Resource Manager

This will prompt to ensure you wish to destroy everything, then will remove all elements of the deployment (effectively destroying all data in the process).  This is not recoverable. 
