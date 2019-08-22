# ---------------------------------------------------------------------------------------------------------------------
# Environmental variables
# You probably want to define these as environmental variables.
# Instructions on that are here: https://github.com/oci-quickstart/oci-prerequisites
# ---------------------------------------------------------------------------------------------------------------------

variable "region" {}
variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}
variable "instances" {}
variable "subnet_id" {}
variable "user_data" {}
variable "ambari_server" {}
variable "ambari_version" {}
variable "hdp_version" {}
variable "hdp_utils_version" {}
variable "deployment_type" {}
variable "cluster_name" {}
variable "image_ocid" {}
variable "AD" {}
variable "worker_node_count" {}

# ---------------------------------------------------------------------------------------------------------------------
# Optional variables
# You can modify these.
# ---------------------------------------------------------------------------------------------------------------------

variable "availability_domain" {
  default = "2"
}

# Number of Master Nodes in the Cluster

variable "master_node_count" {
  default = "2"
}

# Size for NameNode and SecondaryNameNode data volume (Journal Data)

variable "nn_volume_size_in_gbs" {
  default = "500"
}

# 
# Set Cluster Shapes in this section
#

variable "master_instance_shape" {
  default = "VM.Standard2.8"
}

# ---------------------------------------------------------------------------------------------------------------------
# Constants
# You probably don't need to change these.
# ---------------------------------------------------------------------------------------------------------------------
