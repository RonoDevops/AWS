output "vpc_id" {
  value = aws_vpc.this.id
}

output "app_subnet_ids" {
  value = [for s in aws_subnet.app : s.id]
}

output "fsx_security_group_id" {
  value = aws_security_group.fsx.id
}

output "tgw_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "tgw_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.this.id
}

output "file_system_id" {
  value = aws_fsx_ontap_file_system.this.id
}

output "svm_id" {
  value = aws_fsx_ontap_storage_virtual_machine.this.id
}

output "management_ip" {
  description = "Cluster management endpoint (ONTAP REST API / SSH as fsxadmin)"
  value       = one(aws_fsx_ontap_file_system.this.endpoints[0].management[0].ip_addresses)
}

output "intercluster_ips" {
  description = "Intercluster LIF IPs used for cluster peering"
  value       = aws_fsx_ontap_file_system.this.endpoints[0].intercluster[0].ip_addresses
}
