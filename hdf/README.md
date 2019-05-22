# hdf
This is a Terraform template for deploying a fully configured HDF cluster on Oracle Cloud Infrastructure (OCI).

|             | Bastion Instance | Utility and Master Instances |
|-------------|------------------|------------------------------|
| Recommended | VM.Standard2.4   | VM.Standard2.16              |
| Minimum     | VM.Standard2.1   | VM.Standard2.8               |

Host types can be customized in the this template.   Also included with this template is an easy method to customize block volume quantity and size as pertains to HDFS capacity.   See "variables.tf" for more information in-line.

## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oracle/oci-quickstart-prerequisites).

## Scaling

Scale the number of supervisors by incrementing the value of master_node_count in [terraform/variables.tf](terraform/variables.tf) prior to deployment. 

	variable "master_node_count" { default = "3" }

By default this deploys a 3 node cluster.

## Deployment Customization

Deployment customization is done by modifying a few files:
* [scripts/hdf_deploy.sh](scripts/hdf_deploy.sh) Cluster Deployment, customize Ambari admin credentials, HDF version, Cluster Name, Configuration and Cluster Topology.  Configuration and Topology customization requires knowledge of [Ambari Blueprints](https://cwiki.apache.org/confluence/display/AMBARI/Blueprints).  YAML can be modified/inserted into the appropriate section of this script to allow for custom deployment.

        hdf_version
        CLUSTER_NAME
        ambari_login
        ambari_password
	nifi_password

* [scripts/boot.sh](scripts/boot.sh) CloudInit boot script for instances, customize Ambari Agent version.

        ambari_version

* [scripts/boot_ambari.sh](scripts/boot_ambari.sh) CloudInit boot script for Ambari Utility server.  Customize Ambari version.

        ambari_version


## MySQL Server Setup

MySQL Server is installed on the Ambari host for use with Ambari and Cluster Metadata.   The default database passwords are controlled in [scripts/boot_ambari.sh](scripts/boot_ambari.sh).  It is recommended to change these default values prior to deployment:

        mysql_db_password="somepassword"
        ambari_db_password="somepassword"

The "ambari_user" variable is the Database user for Ambari.

## Cluster Security

This template also includes Kerberos Secure Cluster installation by default.   This uses a local KDC on the Utility host.   Administration of Kerberos principals can be done on this host using "kadmin.local" as root user.   Principals are in the format of "<user>/<host_fqdn>@HADOOP.COM".  An admin principal for use with Ambari is also setup as part of deployment, "ambari/admin@HADOOP.COM".

When using secure cluster you should not over-write any of the default principals which are setup by Ambari.

## Deployment

Deploy using standard Terraform commands

	terraform init
	terraform plan
	terraform apply

## Post Deployment

Terraform output will show a script command to deploy the cluster using Ambari Blueprints and Ambari API calls. This is done by building JSON files for host mapping and cluster topology, and submitting them to Ambari API using curl.  The entire process is automated and will give status output as it progresses through the deployment steps.

        ../scripts/hdf_deploy.sh <ambari_server_ip> <availability_domain> <number_of_masters> <master_shape>

## Security and Post-Deployment Auditing

Note that as part of this deployment, ssh keys are used for root level access to provisioned hosts in order to setup software.  The key used is the same as the OPC user which has super-user access to the hosts by default.   If enhanced security is desired, then the following steps should be taken after the Cluster is up and running:

Remove ssh private keys from the Bastion and Utility hosts

        rm -f /home/opc/.ssh/id_rsa

Replace the authorized_keys file in /root/.ssh/ on all hosts with the backup copy

        sudo mv /root/.ssh/authorized_keys.bak /root/.ssh/authorized_keys
