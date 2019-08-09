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

# ---------------------------------------------------------------------------------------------------------------------
# Optional variables
# You can modify these.
# ---------------------------------------------------------------------------------------------------------------------

variable "availability_domain" {
  default = "2"
}

# Number of Workers in the Cluster

variable "worker_node_count" {
  default = "5"
}

variable "replication_factor" {
  default = "3"
}

# Size of each Block Volume used for HDFS /data/
# Minimum recommended size is 700GB per Volume to achieve max IOPS/MBps
# Note that total HDFS capacity per worker is limited by this size.  Until Terraform v0.12 is released, 
# this value will likely be static.  Here is a total capacity per worker list for reference (using 30 volumes per worker):
# 700GB Volume Size = 21 TB per worker
# 1000GB Volume Size = 30 TB per worker
# 2000GB Volume Size = 60 TB per worker

variable "data_blocksize_in_gbs" {
  default = "700"
}

# Desired HDFS Capacity in GB backed by Block Volumes
# This is used to calcuate number of block volumes per worker.  Adjust data_blocksize_in_gbs as appropriate
# based on number of workers.  For example:
# 5 workers @ 700GB Volume Size = Max HDFS Capacity 105 TB, 35 TB Usable with 3x Replication
# 10 workers @ 1TB Volume Size = Max HDFS Capacity 300 TB, 100 TB Usable with 3x Replication
# 10 workers @ 2TB Volume Size = Max HDFS Capacity 600 TB, 200 TB Usable with 3x Replication
# If using DenseIO local storage only - set this to '0'
# If using Heterogenous storage, this will add Block Volume capacity on top of Local storage.
# When using Heterogenous storage - be sure to modify the deploy_on_oci.py and set data_tiering flag to 'True'

variable "hdfs_usable_in_gbs" {
  default = "3000"
}

# Number of Block Volumes per Worker
# Minimum recommended is 3 - Scale up to 32 per compute host
# This is calculated in the template as a combination of DFS replication factor against 
# HDFS Capacity in GBs divided by Block Volume size

variable "block_volumes_per_worker" {
   default = "3"
}

# 
# Set Cluster Shapes in this section
#

variable "worker_instance_shape" {
  default = "BM.DenseIO2.52"
}

# ---------------------------------------------------------------------------------------------------------------------
# Constants
# You probably don't need to change these.
# ---------------------------------------------------------------------------------------------------------------------

// Volume Mapping - used to map Worker Block Volumes consistently to the OS
variable "data_volume_attachment_device" {
  type = "map"
  default = {
    "0" = "/dev/oracleoci/oraclevdf"
    "1" = "/dev/oracleoci/oraclevdg"
    "2" = "/dev/oracleoci/oraclevdh"
    "3" = "/dev/oracleoci/oraclevdi"
    "4" = "/dev/oracleoci/oraclevdj"
    "5" = "/dev/oracleoci/oraclevdk"
    "6" = "/dev/oracleoci/oraclevdl"
    "7" = "/dev/oracleoci/oraclevdm"
    "8" = "/dev/oracleoci/oraclevdn"
    "9" = "/dev/oracleoci/oraclevdo"
    "10" = "/dev/oracleoci/oraclevdp" 
    "11" = "/dev/oracleoci/oraclevdq"
    "12" = "/dev/oracleoci/oraclevdr"
    "13" = "/dev/oracleoci/oraclevds"
    "14" = "/dev/oracleoci/oraclevdt"
    "15" = "/dev/oracleoci/oraclevdu"
    "16" = "/dev/oracleoci/oraclevdv"
    "17" = "/dev/oracleoci/oraclevdw"
    "18" = "/dev/oracleoci/oraclevdx"
    "19" = "/dev/oracleoci/oraclevdy"
    "20" = "/dev/oracleoci/oraclevdz"
    "12" = "/dev/oracleoci/oraclevdab"
    "22" = "/dev/oracleoci/oraclevdac" 
    "23" = "/dev/oracleoci/oraclevdad"
    "24" = "/dev/oracleoci/oraclevdae"
    "25" = "/dev/oracleoci/oraclevdaf"
    "26" = "/dev/oracleoci/oraclevdag"
    "27" = "/dev/oracleoci/oraclevdah"
  }
}
