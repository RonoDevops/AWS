# ☁️ Cloud Architecture Lab

Production-style cloud architectures you can read, deploy and break on purpose.

Each design comes with:

- 📐 **A detailed diagram**: CIDRs, ports, timings, failure domains
- 📄 **A design write-up**: trade-offs, RPO/RTO math, failure modes, cost notes
- 🛠️ **A runnable POC**: Terraform and code to deploy it in your own account
- 📋 **A runbook**: the exact commands for failover, failback and DR drills

## Designs

| # | Design | Focus | Targets |
|---|---|---|---|
| 01 | [FSx for NetApp ONTAP: active/active cross-Region DR](architectures/01-fsx-ontap-active-active-dr/) | Storage · DR · multi-Region | RPO ≤ 5 min · RTO ≤ 15 min |
| 02 | *coming next* | | |

[![FSx ONTAP active/active DR](architectures/01-fsx-ontap-active-active-dr/diagrams/architecture.png)](architectures/01-fsx-ontap-active-active-dr/)

## How to use this repo

1. Read the design README: start with the diagram, then the trade-offs.
2. Deploy the POC in a **sandbox account** (`terraform apply`), follow the setup guide, then run the DR drill.
3. `terraform destroy` when you're done. Several designs use services that bill by the hour.

## Conventions

- Region A = `us-east-1`, Region B = `us-west-2` unless stated otherwise.
- IPs and IDs in diagrams are illustrative.
- Everything here is for learning. Review it against current vendor docs and your own security requirements before production use.

## Contributing

Issues and PRs are welcome: corrections, improved diagrams, or a new design request.

## License

[MIT](LICENSE)
