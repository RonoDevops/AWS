# One Region of the design: VPC, private subnets, Transit Gateway, security groups,
# VPC endpoints and a Multi-AZ FSx for NetApp ONTAP file system with one SVM.

data "aws_region" "current" {}

locals {
  app_subnets = { for i, az in var.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 1) }  # x.x.1.0/24, x.x.2.0/24
  fsx_subnets = { for i, az in var.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 11) } # x.x.11.0/24, x.x.12.0/24
  tags        = merge(var.tags, { Region = data.aws_region.current.name })
}

# ------------------------------------------------------------------ network
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.name}-vpc" })
}

resource "aws_subnet" "app" {
  for_each          = local.app_subnets
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = merge(local.tags, { Name = "${var.name}-app-${each.key}", Tier = "app" })
}

resource "aws_subnet" "fsx" {
  for_each          = local.fsx_subnets
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = merge(local.tags, { Name = "${var.name}-fsx-${each.key}", Tier = "fsx" })
}

# One private route table. FSx Multi-AZ writes its floating-endpoint routes into it,
# so every subnet that must reach the management / data endpoints is associated here.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-private" })
}

resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "fsx" {
  for_each       = aws_subnet.fsx
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Transit Gateway with explicit route tables (no default association/propagation),
# so the inter-Region peering routes are fully under our control.
resource "aws_ec2_transit_gateway" "this" {
  description                     = "${var.name} TGW"
  amazon_side_asn                 = var.tgw_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags                            = merge(local.tags, { Name = "${var.name}-tgw" })
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(local.tags, { Name = "${var.name}-tgw-rt" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id                              = aws_ec2_transit_gateway.this.id
  vpc_id                                          = aws_vpc.this.id
  subnet_ids                                      = [for s in aws_subnet.fsx : s.id]
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags                                            = merge(local.tags, { Name = "${var.name}-tgw-vpc" })
}

resource "aws_ec2_transit_gateway_route_table_association" "vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

# Peer-Region traffic (SnapMirror / FlexCache between intercluster LIFs) leaves via the TGW.
resource "aws_route" "to_peer" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = var.peer_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# ------------------------------------------------------------------ security groups
locals {
  # Client protocols, reachable from both Regions' VPCs (FlexCache / failover clients).
  client_ports = [
    { proto = "tcp", from = 111, to = 111, desc = "NFS portmapper" },
    { proto = "udp", from = 111, to = 111, desc = "NFS portmapper" },
    { proto = "tcp", from = 635, to = 635, desc = "NFS mountd" },
    { proto = "udp", from = 635, to = 635, desc = "NFS mountd" },
    { proto = "tcp", from = 2049, to = 2049, desc = "NFS" },
    { proto = "udp", from = 2049, to = 2049, desc = "NFS" },
    { proto = "tcp", from = 4045, to = 4046, desc = "NFS lock manager / status monitor" },
    { proto = "udp", from = 4045, to = 4046, desc = "NFS lock manager / status monitor" },
    { proto = "tcp", from = 4049, to = 4049, desc = "NFS rquotad" },
    { proto = "udp", from = 4049, to = 4049, desc = "NFS rquotad" },
    { proto = "tcp", from = 445, to = 445, desc = "SMB" },
    { proto = "tcp", from = 3260, to = 3260, desc = "iSCSI" },
    { proto = "tcp", from = 443, to = 443, desc = "ONTAP REST API / System Manager" },
    { proto = "tcp", from = 22, to = 22, desc = "ONTAP CLI (SSH)" },
  ]
  # Cluster peering, SnapMirror and FlexCache between intercluster LIFs.
  intercluster_ports = [
    { proto = "tcp", from = 11104, to = 11104, desc = "Intercluster session management (cluster/SVM peering, SnapMirror control)" },
    { proto = "tcp", from = 11105, to = 11105, desc = "SnapMirror / FlexCache data transfer" },
    { proto = "icmp", from = -1, to = -1, desc = "Cluster peer reachability (ping)" },
  ]
}

resource "aws_security_group" "fsx" {
  name        = "${var.name}-fsx"
  description = "FSx for NetApp ONTAP: client, management and intercluster traffic"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.tags, { Name = "${var.name}-fsx" })
}

resource "aws_vpc_security_group_ingress_rule" "client" {
  for_each = {
    for p in setproduct(local.client_ports, [var.vpc_cidr, var.peer_vpc_cidr]) :
    "${p[0].proto}-${p[0].from}-${p[1]}" => { port = p[0], cidr = p[1] }
  }
  security_group_id = aws_security_group.fsx.id
  ip_protocol       = each.value.port.proto
  from_port         = each.value.port.from
  to_port           = each.value.port.to
  cidr_ipv4         = each.value.cidr
  description       = each.value.port.desc
}

resource "aws_vpc_security_group_ingress_rule" "intercluster" {
  for_each = {
    for p in setproduct(local.intercluster_ports, [var.vpc_cidr, var.peer_vpc_cidr]) :
    "${p[0].proto}-${p[0].from}-${p[1]}" => { port = p[0], cidr = p[1] }
  }
  security_group_id = aws_security_group.fsx.id
  ip_protocol       = each.value.port.proto
  from_port         = each.value.port.from
  to_port           = each.value.port.to
  cidr_ipv4         = each.value.cidr
  description       = each.value.port.desc
}

resource "aws_vpc_security_group_egress_rule" "fsx_all" {
  security_group_id = aws_security_group.fsx.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Replies, AD/DNS lookups, SnapMirror/FlexCache to peer"
}

# Interface endpoints so the in-VPC Lambda reaches AWS APIs without a NAT gateway.
resource "aws_security_group" "endpoints" {
  name        = "${var.name}-vpce"
  description = "Interface VPC endpoints (HTTPS from VPC)"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.tags, { Name = "${var.name}-vpce" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints" {
  security_group_id = aws_security_group.endpoints.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
  description       = "HTTPS from VPC"
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(["secretsmanager", "monitoring", "logs", "sns"])
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.app : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = merge(local.tags, { Name = "${var.name}-vpce-${each.key}" })
}

# ------------------------------------------------------------------ FSx for NetApp ONTAP
resource "aws_fsx_ontap_file_system" "this" {
  deployment_type                   = "MULTI_AZ_1"
  storage_capacity                  = var.fsx_storage_gib
  throughput_capacity               = var.fsx_throughput_mbps
  subnet_ids                        = [for az in var.azs : aws_subnet.fsx[az].id]
  preferred_subnet_id               = aws_subnet.fsx[var.azs[0]].id
  route_table_ids                   = [aws_route_table.private.id]
  endpoint_ip_address_range         = var.fsx_endpoint_ip_range
  security_group_ids                = [aws_security_group.fsx.id]
  fsx_admin_password                = var.fsx_admin_password
  kms_key_id                        = var.kms_key_arn
  automatic_backup_retention_days   = 7
  daily_automatic_backup_start_time = "05:00"
  tags                              = merge(local.tags, { Name = "${var.name}-fsx" })
}

resource "aws_fsx_ontap_storage_virtual_machine" "this" {
  file_system_id             = aws_fsx_ontap_file_system.this.id
  name                       = var.svm_name
  root_volume_security_style = "UNIX"
  svm_admin_password         = var.svm_admin_password
  tags                       = merge(local.tags, { Name = var.svm_name })
  # SMB: add an active_directory_configuration block here pointing at
  # AWS Managed Microsoft AD (multi-Region) once the directory exists.
}
