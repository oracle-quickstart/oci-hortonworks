# Hortonworks HDF on OCI automation with Terraform
Included here is a Terraform template for deploying a fully configured HDF cluster on Oracle Cloud Infrastructure (OCI).

|             | Bastion Instance | Utility and Master Instances |
|-------------|------------------|------------------------------|
| Recommended | VM.Standard2.4   | VM.Standard2.16              |
| Minimum     | VM.Standard2.1   | VM.Standard2.8               |

Host types can be customized in the env-vars file referenced below.   Also included with this template is an easy method to customize block volume quantity and size as pertains to HDFS capacity.   See "variables.tf" for more information in-line.

## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oci-quickstart/oci-prerequisites).

## Scaling

Scale the number of supervisors by incrementing the value of MasterNodeCount in env-vars prior to deployment. 

	export TF_VAR_MasterNodeCount="3" 

By default this deploys a 3 node cluster.

## Password & User Details

Modify the scripts/ambari_setup.sh - This is also where you can customize the HDF & Ambari versions used, along with the Cluster Name.  Default ambari login is "admin/admin" - Change this after logging into Ambari for the first time.

## Deployment

Deploy using standard Terraform commands

	source env-vars
	terraform init
	terraform plan
	terraform apply

## Post Deployment

Post deployment is automated using a scripted process that uses Bash to generate Ambari Blueprints, then submit via Ambari API. Log into the Bastion host after Terraform completes, then run the following commands to watch installation progress.  The public IP will output as a result of the Terraform completion:

        ssh -i ~/.ssh/id_rsa opc@<public_ip_of_bastion>
        sudo screen -r

Ambari is setup as part of this process and will become available just prior to cluster deployment.   Cluster deployment can be monitored in Ambari once it is available, the Ambari URL is presented as part of the Terraform output.

## Security and Post-Deployment Auditing

Note that as part of this deployment, ssh keys are used for root level access to provisioned hosts in order to setup software.  The key used is the same as the OPC user which has super-user access to the hosts by default.   If enhanced security is desired, then the following steps should be taken after the Cluster is up and running:

Remove ssh private keys from the Bastion and Utility hosts

        rm -f /home/opc/.ssh/id_rsa

Replace the authorized_keys file in /root/.ssh/ on all hosts with the backup copy

        sudo mv /root/.ssh/authorized_keys.bak /root/.ssh/authorized_keys
