# ---------------------------------------------------------------------------------------------------------------------
# Environmental variables
# You probably want to define these as environmental variables.
# Instructions on that are here: https://github.com/oci-quickstart/oci-prerequisites
# ---------------------------------------------------------------------------------------------------------------------

variable "region" {}
variable "compartment_ocid" {}
variable "private_key_path" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}
variable "instances" {}
variable "subnet_id" {}
variable "user_data" {}
variable "ambari_server" {}

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

# Path to SSH Key

variable "ssh_keypath" {
  default = "/home/opc/.ssh/id_rsa"
}

# ---------------------------------------------------------------------------------------------------------------------
# Constants
# You probably don't need to change these.
# ---------------------------------------------------------------------------------------------------------------------

// See https://docs.us-phoenix-1.oraclecloud.com/images/
// Oracle-provided image "Oracle-Linux-7.6-2019.03.22-1"
// Kernel Version: 4.14.35-1844.3.2.el7uek.x86_64
variable "InstanceImageOCID" {
  type = "map"
  default = {
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaaqopv4wgbh54jrqoa4bjpkng2y2npzoe2jaj5pdne37ljdxbbbdka"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa2n5z4nmkqjf27btkbdibflwvximz5i3rsz57c3gowckozrdshnua"
    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaaaxnnrqke453ur5katouvfn2i6oweuwpixx6mm5e4nqtci7oztx5a"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaavxqdkuyamlnrdo3q7qa7q3tsd6vnyrxjy3nmdbpv7fs7um53zh5q"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaapxvrtwbpgy3lchk2usn462ekarljwg4zou2acmundxlkzdty4bjq"
  }
}

