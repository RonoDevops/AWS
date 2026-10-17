# DR runbook: Region failover and failback

The steps below use `/orders` (owner: Region A) as the example. For `/media`, swap A ↔ B and the volume names.

| Scenario | What happens | Who acts | Target |
|---|---|---|---|
| Node/AZ failure in a Region | FSx Multi-AZ fails over to the standby node automatically | nobody | ~60 s, RPO 0 |
| SnapMirror lag > 300 s | WARN alarm → on-call investigates (throughput, TGW, peer health) | on-call | before CRIT |
| Region A unavailable | Route 53 moves app traffic to B; `/orders` is promoted in B (**this runbook**) | incident commander approves, SSM / operator executes | RTO ≤ 15 min, RPO ≤ 5 min + last transfer |

> **Why failover isn't automatic:** If the old origin were still writing during a network partition, auto-promotion would give you two writable copies (split brain).
> The 30 s Route 53 detection is automatic; promoting storage needs one human approval.

---

## A. Unplanned failover: Region A lost

**T+0 to T+3 min: detect**

- Route 53 health checks on the Region A ALB fail (10 s × 3), and latency records stop answering with A.
- The `SnapMirror unhealthy svm_b:vol_orders_dr` alarm fires (peer unreachable).
- Confirm on the AWS Health Dashboard and with the application owners. **Declare the incident.**

**T+3 to T+8 min: decide and record the data-loss window**

```text
[B] snapmirror show -destination-path svm_b:vol_orders_dr -fields lag-time,newest-snapshot,newest-snapshot-timestamp
```

Record `lag-time`. That's the actual RPO for this event, and it goes in the incident log.

**T+8 to T+10 min: promote `/orders` in Region B**

```text
[B] snapmirror quiesce -destination-path svm_b:vol_orders_dr
[B] snapmirror break   -destination-path svm_b:vol_orders_dr        # DP -> RW
[B] volume unmount -vserver svm_b -volume vol_orders_cache          # cache can't reach its origin
[B] volume unmount -vserver svm_b -volume vol_orders_dr
[B] volume mount   -vserver svm_b -volume vol_orders_dr -junction-path /orders
[B] volume show -vserver svm_b -volume vol_orders_dr -fields type,junction-path   # type RW, /orders
```

**T+10 to T+15 min: clients and traffic**

- On Region B app hosts, remount `/orders`. The junction now points to a different volume, so NFS clients holding the old handles get `ESTALE`.

  ```bash
  sudo umount -l /mnt/orders && sudo mount -a
  ```

- Scale the Region B app tier (ASG / EKS node group) to full production capacity.
- Check Route 53: only Region B records answer, `dig app.example.com` returns the B ALB, and the TTL is 60 s.
- Smoke test: write a file under `/mnt/orders` and read it back.

**After stabilization**

- `/media` in Region B wasn't affected (B owns it).
- Keep the Region A volumes untouched for forensics until failback.

## B. Planned failover (drill / maintenance, RPO 0)

1. Stop writes to `/orders` in Region A (put the app in maintenance mode).
2. Run a final transfer and confirm it's idle:
   ```text
   [B] snapmirror update -destination-path svm_b:vol_orders_dr
   [B] snapmirror show -destination-path svm_b:vol_orders_dr -fields status,lag-time   # Idle, lag ≈ 0
   ```
3. Run the promote steps from A (quiesce → break → remount), then the client steps.
4. Reverse replication right away with step C.1, so Region A becomes the DR copy.

## C. Failback to Region A

**C.1 Reverse-resync B → A (once Region A is healthy)**

> ⚠️ `resync` rolls `vol_orders` in A back to the last common snapshot. Any writes A accepted that never replicated (up to one interval) are discarded.
> If you need them, run `volume clone create -vserver svm_a -flexclone vol_orders_preresync -parent-volume vol_orders` first.

```text
[A] volume unmount -vserver svm_a -volume vol_orders
[A] snapmirror create -source-path svm_b:vol_orders_dr -destination-path svm_a:vol_orders -policy MirrorAllSnapshots -schedule 5min
[A] snapmirror resync -destination-path svm_a:vol_orders
[A] snapmirror show   -destination-path svm_a:vol_orders -fields state,lag-time   # Snapmirrored
```

**C.2 Cut back in a maintenance window**

```text
# stop writes to /orders in Region B
[A] snapmirror update  -destination-path svm_a:vol_orders
[A] snapmirror quiesce -destination-path svm_a:vol_orders
[A] snapmirror break   -destination-path svm_a:vol_orders
[A] volume mount -vserver svm_a -volume vol_orders -junction-path /orders
```

**C.3 Restore the original topology**

```text
[B] volume unmount -vserver svm_b -volume vol_orders_dr
[B] snapmirror resync -destination-path svm_b:vol_orders_dr             # original A -> B relationship
[B] volume mount -vserver svm_b -volume vol_orders_dr    -junction-path /dr/orders
[B] volume mount -vserver svm_b -volume vol_orders_cache -junction-path /orders

[A] snapmirror delete  -destination-path svm_a:vol_orders               # remove the temporary reverse relationship
[B] snapmirror release -destination-path svm_a:vol_orders -relationship-info-only true
```

Remount `/orders` on the app hosts in both Regions, put the Region A app tier back in service, and confirm the CloudWatch lag saw-tooth is back under 300 s.

## D. Non-disruptive DR test (monthly)

Test against a FlexClone of the DP volume. Replication keeps running and the RPO is unaffected.

```text
[B] volume clone create -vserver svm_b -flexclone vol_orders_drtest -parent-volume vol_orders_dr -junction-path /drtest/orders
#   point a test copy of the app in Region B at /drtest/orders, validate data and app start-up time
[B] volume unmount -vserver svm_b -volume vol_orders_drtest
[B] volume offline -vserver svm_b -volume vol_orders_drtest
[B] volume delete  -vserver svm_b -volume vol_orders_drtest
```

Record the measured RTO for each drill.
