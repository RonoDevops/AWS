# ONTAP setup: peering, SnapMirror and FlexCache

Terraform builds the network, both file systems, the SVMs and the RW/DP volumes.
The FSx API doesn't manage cluster peering, SnapMirror or FlexCache, so you do those steps in the ONTAP CLI.

Connect to each cluster's management endpoint (`terraform output`) over SSH (TCP 22) as `fsxadmin`.
Run this from a bastion or SSM-managed instance in one of the VPCs. The password is in the Secrets Manager secret listed in the outputs.

```bash
ssh fsxadmin@<management_ip>
```

> Commands marked **[A]** run on the Region A cluster (us-east-1), **[B]** on Region B (us-west-2).

---

## 0. Collect identifiers

```text
[A] cluster identity show                     # -> cluster name, e.g. FsxId0aaa...
[A] network interface show -role intercluster # -> inter_1 / inter_2 IPs (10.10.11.x / 10.10.12.x)
[B] cluster identity show
[B] network interface show -role intercluster # -> 10.20.11.x / 10.20.12.x
```

## 1. Cluster peering (TCP 11104 + ICMP between intercluster LIFs)

```text
[B] cluster peer create -address-family ipv4 -peer-addrs <A_inter_1>,<A_inter_2>
      # enter + confirm a passphrase (≥ 8 chars)
[A] cluster peer create -address-family ipv4 -peer-addrs <B_inter_1>,<B_inter_2>
      # enter the SAME passphrase

[A] cluster peer show -instance               # Availability: Available
[A] cluster peer health show                  # all nodes: Data Ping / ICMP ok
```

If the peer stays `Unavailable`, check the TGW routes and both FSx security groups for 11104/11105/ICMP.

## 2. SVM peering (both applications we need)

```text
[B] vserver peer create -vserver svm_b -peer-vserver svm_a -peer-cluster <A_cluster_name> -applications snapmirror,flexcache
[A] vserver peer accept -vserver svm_a -peer-vserver svm_b
[A] vserver peer show                         # Peer State: peered
```

## 3. The 5-minute schedule

ONTAP ships a `5min` cron schedule. Check that it exists, and create it if it doesn't:

```text
[A] job schedule cron show -name 5min
[A] job schedule cron create -name 5min -minute 0,5,10,15,20,25,30,35,40,45,50,55
    # repeat on [B]
```

## 4. SnapMirror ① /orders A → B (created on the destination)

```text
[B] snapmirror create -source-path svm_a:vol_orders -destination-path svm_b:vol_orders_dr -policy MirrorAllSnapshots -schedule 5min
[B] snapmirror initialize -destination-path svm_b:vol_orders_dr
[B] snapmirror show -destination-path svm_b:vol_orders_dr -fields state,status,healthy,lag-time,last-transfer-duration
      # state: Snapmirrored · status: Idle · healthy: true · lag-time < 0:05:00
[B] volume mount -vserver svm_b -volume vol_orders_dr -junction-path /dr/orders
```

## 5. SnapMirror ② /media B → A

```text
[A] snapmirror create -source-path svm_b:vol_media -destination-path svm_a:vol_media_dr -policy MirrorAllSnapshots -schedule 5min
[A] snapmirror initialize -destination-path svm_a:vol_media_dr
[A] snapmirror show -destination-path svm_a:vol_media_dr -fields state,status,healthy,lag-time
[A] volume mount -vserver svm_a -volume vol_media_dr -junction-path /dr/media
```

## 6. FlexCache ③ ④ (global namespace, TCP 11105)

The cache volume takes the origin's junction path in the peer Region, so `/orders` and `/media` resolve in both Regions.

```text
[B] volume flexcache create -vserver svm_b -volume vol_orders_cache -aggr-list aggr1 -size 100g -origin-vserver svm_a -origin-volume vol_orders -junction-path /orders
[A] volume flexcache create -vserver svm_a -volume vol_media_cache  -aggr-list aggr1 -size 100g -origin-vserver svm_b -origin-volume vol_media  -junction-path /media
[A] volume flexcache show
```

## 7. NFS exports

POC rule: allow both VPCs. In production, use per-subnet rules, `krb5p` and `-superuser none`.

```text
[A] vserver export-policy rule create -vserver svm_a -policyname default -clientmatch 10.10.0.0/16,10.20.0.0/16 -protocol nfs4 -rorule sys -rwrule sys -superuser sys
[B] vserver export-policy rule create -vserver svm_b -policyname default -clientmatch 10.10.0.0/16,10.20.0.0/16 -protocol nfs4 -rorule sys -rwrule sys -superuser sys
```

## 8. Mount from clients

The SVM NFS DNS name is shown in the console (Storage virtual machine → Endpoints), e.g. `svm-0123.fs-0abc.fsx.us-east-1.amazonaws.com`.

```bash
# Region A app hosts
sudo mount -t nfs -o nfsvers=4.1,hard,timeo=600,retrans=2,rsize=1048576,wsize=1048576 <svm_a_nfs_dns>:/orders /mnt/orders
sudo mount -t nfs -o nfsvers=4.1,hard,timeo=600,retrans=2,rsize=1048576,wsize=1048576 <svm_a_nfs_dns>:/media  /mnt/media
# Region B app hosts: the same paths on <svm_b_nfs_dns>
```

## 9. Verify the RPO

```text
[B] snapmirror show -fields lag-time,last-transfer-size,last-transfer-duration
```

The CloudWatch metric `Custom/FSxONTAP SnapMirrorLagSeconds` should follow a saw-tooth that stays below 300 s.
If `last-transfer-duration` keeps creeping toward the 5-minute interval, raise throughput capacity or reduce the change rate (see "Sizing" in the README).
