variable "name" {
  description = "Name prefix for this Region's resources"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for this Region"
  type        = string
}

variable "peer_vpc_cidr" {
  description = "VPC CIDR of the other Region (allowed for SnapMirror / FlexCache / clients)"
  type        = string
}

variable "azs" {
  description = "Exactly two AZ names: [preferred, standby]"
  type        = list(string)
  validation {
    condition     = length(var.azs) == 2
    error_message = "Multi-AZ FSx for ONTAP needs exactly two AZs."
  }
}

variable "tgw_asn" {
  description = "Amazon-side ASN for the Transit Gateway (must differ between Regions)"
  type        = number
}

variable "fsx_storage_gib" {
  description = "SSD storage capacity in GiB"
  type        = number
  default     = 1024
}

variable "fsx_throughput_mbps" {
  description = "Throughput capacity in MBps (MULTI_AZ_1: 128, 256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "fsx_endpoint_ip_range" {
  description = "Floating endpoint range outside the VPC CIDR; keep it distinct per Region"
  type        = string
}

variable "fsx_admin_password" {
  type      = string
  sensitive = true
}

variable "svm_admin_password" {
  type      = string
  sensitive = true
}

variable "svm_name" {
  type = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for encryption at rest (null = AWS managed key)"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
