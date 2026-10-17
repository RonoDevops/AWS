variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "fsxdr"
}

variable "region_a" {
  type    = string
  default = "us-east-1"
}

variable "region_b" {
  type    = string
  default = "us-west-2"
}

variable "azs_a" {
  description = "[preferred, standby] AZs in Region A"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "azs_b" {
  description = "[preferred, standby] AZs in Region B"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "vpc_cidr_a" {
  type    = string
  default = "10.10.0.0/16"
}

variable "vpc_cidr_b" {
  type    = string
  default = "10.20.0.0/16"
}

variable "fsx_storage_gib" {
  description = "SSD capacity per file system (POC default 1 TiB)"
  type        = number
  default     = 1024
}

variable "fsx_throughput_mbps" {
  description = "Throughput per file system; size so a 5-minute change set replicates well inside 5 minutes"
  type        = number
  default     = 512
}

variable "volume_size_mib" {
  description = "Size of each volume in MiB"
  type        = number
  default     = 102400 # 100 GiB
}

variable "skip_final_backup" {
  description = "POC convenience: skip the final backup on destroy"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email subscribed to the DR alert SNS topics (null to skip)"
  type        = string
  default     = null
}

variable "tags" {
  type = map(string)
  default = {
    Project = "cloud-architecture-lab"
    Pattern = "fsx-ontap-active-active-dr"
  }
}
