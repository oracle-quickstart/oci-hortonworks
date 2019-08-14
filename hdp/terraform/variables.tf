# ---------------------------------------------------------------------------------------------------------------------
# Hadoop Variables
# These can be modified to customize deployment
# ---------------------------------------------------------------------------------------------------------------------

variable "ssh_public_key" {}

variable "ssh_private_key" {}

variable "ambari_version" {
  default = "2.6.2.2"
}

variable "hdp_version" {
  default = "2.6.5.0"
}

variable "hdp_utils_version" {
  default = "1.1.0.22"
}

variable "cluster_name" {
  default = "TestCluster"
}

variable "deployment_type" {
  default = "simple"
}

variable "worker_instance_shape" {
  default = "BM.DenseIO2.52"
}

variable "worker_node_count" {
  default = "3"
}

variable "data_blocksize_in_gbs" {
  default = "700"
}

variable "block_volumes_per_worker" {
   default = "0"
}

variable "master_instance_shape" {
  default = "VM.Standard2.16"
}

variable "master_node_count" {
  default = "3"
}

variable "nn_volume_size_in_gbs" {
  default = "500"
}

variable "bastion_instance_shape" {
  default = "VM.Standard2.4"
}

variable "utility_instance_shape" {
  default = "VM.Standard2.8"
}

# ---------------------------------------------------------------------------------------------------------------------
# Optional variables
# You can modify these.
# ---------------------------------------------------------------------------------------------------------------------

variable "tenancy_ocid" {}
variable "region" {}
variable "compartment_ocid" {}
variable "availability_domain" {
  default = "1"
}

# ---------------------------------------------------------------------------------------------------------------------
# Constants
# You probably don't need to change these.
# ---------------------------------------------------------------------------------------------------------------------

// See https://docs.us-phoenix-1.oraclecloud.com/images/
// Oracle-provided image "Oracle-Linux-7.6-2019.08.02-0"
// Kernel Version: kernel-uek-4.14.35-1902.3.2.el7uek.x86_64
variable "InstanceImageOCID" {
  type = "map"
  default = {
    ap-mumbai-1 = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaajc74fbcjvb6fm55ij6pfi6fgp6t4r4axfwbh3hkb6fjwpvt64xta"
    ap-seoul-1 = "ocid1.image.oc1.ap-seoul-1.aaaaaaaacdrxj4ktv6qilozzc7bkhcrdlzri2gw4imlljpg255stxvkbgpnq"
    ap-tokyo-1 = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaasd7bfo4bykdf3jlb7n5j46oeqxwj2r3ub4ly36db3pmrlmlzzv3a"
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaa3i4wzxnwlfgizjv4usrz2fh7dhgolp5dmrmmqcm4i7bdhkbdracq"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaax3xjmpwufw6tucuoyuenletg74sdsj5f2gzsvlv4mqbbgeokqzsq"
    eu-zurich-1 = "ocid1.image.oc1.eu-zurich-1.aaaaaaaa5cd4xnyw6udl5u7v7acgpc4a3xpkwirk7xg2oliq53ea2gmrqheq"
    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaaokbcnsqwbrgz2wiif2s452u2a4o674tnjsamja5rhtpml5a7sana"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaasorq3smbazoxvyqozz52ch5i5cexjojb7qvcefa5ubij2yjycy2a"
    us-langley-1 = "ocid1.image.oc2.us-langley-1.aaaaaaaad225yfhwxrkt4aprxf6erfhtiubrrq3ythktnuv4vu5lzgqowgsa"
    us-luke-1 = "ocid1.image.oc2.us-luke-1.aaaaaaaat37ujafbrdcdfirlfhwzsozyp4lnvzbv2ubiy2p6ob6q3lekpgjq"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaaa3vjdblyvw6rlz3jhjxudf6dpqsazqfynn3ziqrxyfox2wq5bdaq"
  }
}

variable "oci_service_gateway" {
  type = "map"
  default = {
    ap-seoul-1 = "all-seo-services-in-oracle-services-network"
    ap-tokyo-1 = "all-hnd-services-in-oracle-services-network"
    ca-toronto-1 = "all-yyz-services-in-oracle-services-network"
    eu-frankfurt-1 = "all-fra-services-in-oracle-services-network"
    uk-london-1 = "all-lhr-services-in-oracle-services-network"
    us-ashburn-1 = "all-iad-services-in-oracle-services-network"
    us-phoenix-1 = "all-phx-services-in-oracle-services-network"
  }
}

