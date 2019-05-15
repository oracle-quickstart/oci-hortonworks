# Hortonworks HDP on OCI automation with Terraform
Included here is a Terraform template for deploying a fully configured HDP cluster on OCI..

|             | Worker Nodes   | Bastion Instance | Utility and Master Instances |
|-------------|----------------|------------------|------------------------------|
| Recommended | BM.DenseIO2.52 | VM.Standard2.4   | VM.Standard2.16              |
| Minimum     | VM.Standard2.8 | VM.Standard2.1   | VM.Standard2.8               |

Host types can be customized in this template.   Also included with this template is an easy method to customize block volume quantity and size as pertains to HDFS capacity.   See "variables.tf" for more information in-line.

## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oracle/oci-quickstart-prerequisites).

## Scaling

Modify the "variables.tf" file prior to deployment and set the number of workers to scale your cluster dynamically.

	variable "nodecount" { default = "5" }

The above deploys a 5 worker cluster.

## Block Volumes

By default this template is setup to use DenseIO Bare Metal shapes using local NVME for HDFS.  If you want to use Block Volumes instead, a template is included.  This template attaches 12 Block Volumes per Worker, the size of each volume can be specified in variables.tf.   The minimum recommended size per volume is 700GB to maximize per-volume throughput.  It is recommended no less than 4 volumes are attached per Worker.   This can be customized by removing stanzas from block.tf.

Note that it is also highly suggested to add dependencies for Block Volume attachments to remote-exec.tf when using Block Volumes, which ensures the volumes are created and attached before cluster provisioning.  This is done by modifying the depends_on line as follows:

	depends_on = ["oci_core_instance.UtilityNode","oci_core_instance.MasterNode","oci_core_instance.WorkerNode","oci_core_instance.Bastion","oci_core_volume_attachment.Worker1","oci_core_volume_attachment.Worker2","oci_core_volume_attachment.Worker3","oci_core_volume_attachment.Worker4","oci_core_volume_attachment.Worker5","oci_core_volume_attachment.Worker6","oci_core_volume_attachment.Worker7","oci_core_volume_attachment.Worker8","oci_core_volume_attachment.Worker9","oci_core_volume_attachment.Worker10","oci_core_volume_attachment.Worker11","oci_core_volume_attachment.Worker12"]

## Password & User Details

Modify the scripts/Ambari_setup.sh - This is also where you can customize the HDP & Ambari versions used, along with the Cluster Name.  Default ambari login is "admin/admin" - Change this after logging into Ambari for the first time.

## Deployment

Deploy using standard Terraform commands

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
