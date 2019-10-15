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
// Oracle-provided image "Oracle-Linux-7.6-2019.07.15-0"
// Kernel Version: kernel-uek-4.14.35-1902.3.1.el7uek.x86_64
variable "InstanceImageOCID" {
  type = "map"
  default = {
    ap-mumbai-1 = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaa74noijy4xbexah6elqtagiz2sr5rrmhp3iwph5c2esyauahgwk2q"
    ap-seoul-1 = "ocid1.image.oc1.ap-seoul-1.aaaaaaaavntl5tdffjuhbuugj73cnwwd5z5obel4ivtxgeaicfofamjelh7q"
    ap-tokyo-1 = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaann6woj2cm3hguypjfx3ubv6lnwlk3x36kz775p273nvflgwy5fqq"
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaat5xofe3k4wj55yikzpz33xcz6td5h7kb5x3vch555qt54ok3anva"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaakuepu6owftdo3qq2rftcoiwdhyj5jjxfdws6gxnv5gpdxpvtjnrq"
    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaavrftjg3fa2uw5ndqin3tjme3jc4vpxnsysoxetlswsr6aqlfwurq"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaa5m7pxvywx2isnwon3o3kixkk6gq4tmdtfgvctj7xbl3wgo56uppa"
    us-langley-1 = "ocid1.image.oc2.us-langley-1.aaaaaaaa6mdubne7lvp75ttl32zyjurarnp6u3qazfj3nleinwd4xfryaomq"
    us-luke-1 = "ocid1.image.oc2.us-luke-1.aaaaaaaaunosincqm2bctskhewtkvqjy3awunwwm7mdcelitps2t33mdneva"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaajpign274mukkdwjqbzqanem4xqcmvu4mip3jbf5kzhrplqjwdkfq"
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

