# Usage Guide

## PREREQUISITES

Installation has a dependency on Terraform being installed and configured for the user tenancy.   As such an "env-vars" file is included with this package that contains all the necessary environment variables.  This file should be updated with the appropriate values prior to installation.  To source this file prior to installation, either reference it in your .rc file for your shell's or run the following:

        source env-vars

## Scaling

Scale the number of supervisors by incrementing the value of MasterNodeCount in env-vars prior to deployment.  

## Password & User Details

Modify the scripts/ambari_setup.sh - This is also where you can customize the HDF & Ambari versions used, along with the Cluster Name.  Default ambari login is "admin/admin" - Change this after logging into Ambari for the first time.

## Deployment

Deploy using standard Terraform commands

        terraform init && terraform plan && terraform apply

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
