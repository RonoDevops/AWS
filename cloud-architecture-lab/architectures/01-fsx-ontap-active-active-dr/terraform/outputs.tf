output "region_a" {
  value = {
    file_system_id   = module.region_a.file_system_id
    svm_id           = module.region_a.svm_id
    management_ip    = module.region_a.management_ip
    intercluster_ips = module.region_a.intercluster_ips
    alerts_topic     = module.monitoring_a.sns_topic_arn
    fsxadmin_secret  = module.monitoring_a.secret_arn
  }
}

output "region_b" {
  value = {
    file_system_id   = module.region_b.file_system_id
    svm_id           = module.region_b.svm_id
    management_ip    = module.region_b.management_ip
    intercluster_ips = module.region_b.intercluster_ips
    alerts_topic     = module.monitoring_b.sns_topic_arn
    fsxadmin_secret  = module.monitoring_b.secret_arn
  }
}

output "next_step" {
  value = "Peer the clusters and create SnapMirror + FlexCache: see ../docs/ontap-setup.md"
}
