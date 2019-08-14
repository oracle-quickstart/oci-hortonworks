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
// Oracle-provided image "CentOS-7-2019.07.18-0"
variable "InstanceImageOCID" {
  type = "map"
  default = {
    ap-mumbai-1 = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaaojdjmlt7hhhyu6ev77fptrpcjza2elnhubmhauxx7ik53g3k4clq"
    ap-seoul-1 = "ocid1.image.oc1.ap-seoul-1.aaaaaaaa2liqaihg2b3dlxl54zqyt7zjvmxdunp6buivbtqhhvurnpepbvta"
    ap-tokyo-1 = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaa7cjkigefv2b3hi32ku4yhwvbtlbn6ektgy25xuopekbcfltequxq"
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaapgumj7xlcpfqugii7i7y722rfaib7xsc4tnoeikwwtsrrqxzf5qq"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaassfjfflfwty6c24gxoou224djh7rfm3cdnnq5v2jcx6eslwx4fpa"
    eu-zurich-1 = "ocid1.image.oc1.eu-zurich-1.aaaaaaaaqsi7yuqw7jk3wslena3lvpaxrtzpvoz7kelomvpwpdly7me3sixq"
    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaajyqa7buxw3jkgs5krmxmlnsek24dpby52scb7wsfln55cixusooa"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaatp4lxfmhmzebvfsw54tttkiv4jarrohqykbtmee5x2smxlqnr75a"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaava2go3l5jvj2ypu6poqgvhzypdwg6qbhkcs5etxewvulgizxy6fa"
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

