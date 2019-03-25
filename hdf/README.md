# Hortonworks HDF on OCI automation with Terraform
Included here is a Terraform template for deploying a fully configured HDF cluster on Oracle Cloud Infrastructure (OCI).

## N-Node 
This is an [N-Node](N-Node) template allowing for dynamic number of Master Nodes (Supervisors) to be deployed with HDF.

## How to use this template
In addition to an active tenancy on OCI, you will need a functional installation of Terraform, and an API key for a privileged user in the tenancy.  See these documentation links for more information:

* [Getting Started with Terraform on OCI](https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/terraformgetstarted.htm)
* [How to Generate an API Signing Key](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/apisigningkey.htm#How)

Once the pre-requisites are in place, you will need to copy the template from this repository to where you have Terraform installed.  Refer to the README.md for the template for additional deployment instructions.
