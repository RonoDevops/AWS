terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.70" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  alias  = "a"
  region = var.region_a
  default_tags { tags = var.tags }
}

provider "aws" {
  alias  = "b"
  region = var.region_b
  default_tags { tags = var.tags }
}

# ------------------------------------------------------------------ credentials
resource "random_password" "fsxadmin" {
  for_each         = toset(["a", "b"])
  length           = 24
  special          = true
  override_special = "#%+-_"
}

resource "random_password" "vsadmin" {
  for_each         = toset(["a", "b"])
  length           = 24
  special          = true
  override_special = "#%+-_"
}

# ------------------------------------------------------------------ Regions
module "region_a" {
  source    = "./modules/region"
  providers = { aws = aws.a }

  name                  = "${var.name}-a"
  vpc_cidr              = var.vpc_cidr_a
  peer_vpc_cidr         = var.vpc_cidr_b
  azs                   = var.azs_a
  tgw_asn               = 64512
  fsx_storage_gib       = var.fsx_storage_gib
  fsx_throughput_mbps   = var.fsx_throughput_mbps
  fsx_endpoint_ip_range = "198.19.255.0/24"
  fsx_admin_password    = random_password.fsxadmin["a"].result
  svm_admin_password    = random_password.vsadmin["a"].result
  svm_name              = "svm_a"
}

module "region_b" {
  source    = "./modules/region"
  providers = { aws = aws.b }

  name                  = "${var.name}-b"
  vpc_cidr              = var.vpc_cidr_b
  peer_vpc_cidr         = var.vpc_cidr_a
  azs                   = var.azs_b
  tgw_asn               = 64513
  fsx_storage_gib       = var.fsx_storage_gib
  fsx_throughput_mbps   = var.fsx_throughput_mbps
  fsx_endpoint_ip_range = "198.19.254.0/24"
  fsx_admin_password    = random_password.fsxadmin["b"].result
  svm_admin_password    = random_password.vsadmin["b"].result
  svm_name              = "svm_b"
}

# ------------------------------------------------------------------ inter-Region TGW peering
data "aws_caller_identity" "current" {
  provider = aws.a
}

resource "aws_ec2_transit_gateway_peering_attachment" "a_to_b" {
  provider                = aws.a
  transit_gateway_id      = module.region_a.tgw_id
  peer_transit_gateway_id = module.region_b.tgw_id
  peer_region             = var.region_b
  peer_account_id         = data.aws_caller_identity.current.account_id
  tags                    = { Name = "${var.name}-a-to-b" }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "b" {
  provider                      = aws.b
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.a_to_b.id
  tags                          = { Name = "${var.name}-b-from-a" }
}

resource "aws_ec2_transit_gateway_route_table_association" "peer_a" {
  provider                       = aws.a
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.a_to_b.id
  transit_gateway_route_table_id = module.region_a.tgw_route_table_id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.b]
}

resource "aws_ec2_transit_gateway_route_table_association" "peer_b" {
  provider                       = aws.b
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.b.transit_gateway_attachment_id
  transit_gateway_route_table_id = module.region_b.tgw_route_table_id
}

# Peering attachments do not propagate routes: static routes in both directions.
resource "aws_ec2_transit_gateway_route" "a_to_b" {
  provider                       = aws.a
  destination_cidr_block         = var.vpc_cidr_b
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.a_to_b.id
  transit_gateway_route_table_id = module.region_a.tgw_route_table_id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.b]
}

resource "aws_ec2_transit_gateway_route" "b_to_a" {
  provider                       = aws.b
  destination_cidr_block         = var.vpc_cidr_a
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.b.transit_gateway_attachment_id
  transit_gateway_route_table_id = module.region_b.tgw_route_table_id
}

# ------------------------------------------------------------------ volumes
# Region A owns /orders, Region B owns /media. Each Region holds a DP (read-only)
# SnapMirror destination of the other's dataset. SnapMirror relationships and
# FlexCache volumes are created with the ONTAP CLI (docs/ontap-setup.md) because the
# FSx API does not manage them.

resource "aws_fsx_ontap_volume" "orders" {
  provider                   = aws.a
  name                       = "vol_orders"
  storage_virtual_machine_id = module.region_a.svm_id
  ontap_volume_type          = "RW"
  junction_path              = "/orders"
  size_in_megabytes          = var.volume_size_mib
  storage_efficiency_enabled = true
  security_style             = "UNIX"
  snapshot_policy            = "default"
  tiering_policy {
    name           = "AUTO"
    cooling_period = 31
  }
  skip_final_backup = var.skip_final_backup
}

resource "aws_fsx_ontap_volume" "orders_dr" {
  provider                   = aws.b
  name                       = "vol_orders_dr"
  storage_virtual_machine_id = module.region_b.svm_id
  ontap_volume_type          = "DP"
  size_in_megabytes          = var.volume_size_mib
  tiering_policy {
    name = "ALL"
  }
  skip_final_backup = var.skip_final_backup
}

resource "aws_fsx_ontap_volume" "media" {
  provider                   = aws.b
  name                       = "vol_media"
  storage_virtual_machine_id = module.region_b.svm_id
  ontap_volume_type          = "RW"
  junction_path              = "/media"
  size_in_megabytes          = var.volume_size_mib
  storage_efficiency_enabled = true
  security_style             = "UNIX"
  snapshot_policy            = "default"
  tiering_policy {
    name           = "AUTO"
    cooling_period = 31
  }
  skip_final_backup = var.skip_final_backup
}

resource "aws_fsx_ontap_volume" "media_dr" {
  provider                   = aws.a
  name                       = "vol_media_dr"
  storage_virtual_machine_id = module.region_a.svm_id
  ontap_volume_type          = "DP"
  size_in_megabytes          = var.volume_size_mib
  tiering_policy {
    name = "ALL"
  }
  skip_final_backup = var.skip_final_backup
}

# ------------------------------------------------------------------ monitoring (destination side)
module "monitoring_a" {
  source    = "./modules/monitoring"
  providers = { aws = aws.a }

  name               = "${var.name}-a"
  management_ip      = module.region_a.management_ip
  subnet_ids         = module.region_a.app_subnet_ids
  vpc_id             = module.region_a.vpc_id
  fsx_admin_password = random_password.fsxadmin["a"].result
  destination_paths  = ["svm_a:vol_media_dr"]
  alarm_email        = var.alarm_email
}

module "monitoring_b" {
  source    = "./modules/monitoring"
  providers = { aws = aws.b }

  name               = "${var.name}-b"
  management_ip      = module.region_b.management_ip
  subnet_ids         = module.region_b.app_subnet_ids
  vpc_id             = module.region_b.vpc_id
  fsx_admin_password = random_password.fsxadmin["b"].result
  destination_paths  = ["svm_b:vol_orders_dr"]
  alarm_email        = var.alarm_email
}
