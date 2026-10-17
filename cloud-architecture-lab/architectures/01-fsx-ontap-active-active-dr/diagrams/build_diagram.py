#!/usr/bin/env python3
"""Generates architecture.svg for the FSx for NetApp ONTAP active/active cross-region DR design.

Edit the data below and re-run:  python3 build_diagram.py
"""
from html import escape
from pathlib import Path

W, H = 1800, 1430
FONT = "'Amazon Ember','Helvetica Neue',Helvetica,Arial,sans-serif"

# AWS architecture-icon palette
C = {
    "ink": "#232F3E", "muted": "#545B64", "line": "#879196",
    "region": "#00A4A6", "vpc": "#8C4FFF", "az": "#147EBA",
    "subnet": "#E6F6F7", "storage": "#7AA116", "storage_bg": "#F2F8E8",
    "net": "#8C4FFF", "compute": "#ED7100", "mgmt": "#E7157B",
    "sec": "#DD344C", "app": "#C925D1",
    "rep_a": "#1A7F37", "rep_b": "#0B5CAD", "cache": "#B45309",
}

out = []


def add(s):
    out.append(s)


def text(x, y, s, size=11, weight="normal", fill=None, anchor="start", italic=False):
    style = "font-style:italic;" if italic else ""
    add(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" '
        f'fill="{fill or C["ink"]}" text-anchor="{anchor}" style="{style}">{escape(s)}</text>')


def lines(x, y, rows, size=11, gap=None, **kw):
    gap = gap or size + 4
    for i, r in enumerate(rows):
        if isinstance(r, tuple):
            s, extra = r
            text(x, y + i * gap, s, size=size, **{**kw, **extra})
        else:
            text(x, y + i * gap, r, size=size, **kw)


def box(x, y, w, h, stroke, fill="#FFFFFF", dash=None, rx=6, sw=1.5):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" '
        f'stroke="{stroke}" stroke-width="{sw}"{d}/>')


def tag(x, y, label, color, w=None):
    w = w or (len(label) * 6.6 + 14)
    add(f'<rect x="{x}" y="{y}" width="{w}" height="18" rx="3" fill="{color}"/>')
    text(x + w / 2, y + 13, label, size=10.5, weight="bold", fill="#FFFFFF", anchor="middle")
    return w


def icon(x, y, color, glyph, s=34):
    add(f'<rect x="{x}" y="{y}" width="{s}" height="{s}" rx="5" fill="{color}"/>')
    text(x + s / 2, y + s / 2 + 4.5, glyph, size=12 if len(glyph) < 4 else 10, weight="bold",
         fill="#FFFFFF", anchor="middle")


def arrow(x1, y1, x2, y2, color, dash=None, both=False, sw=2.2, mid=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    ms = f' marker-start="url(#a-{color[1:]})"' if both else ""
    if mid:
        path = f"M{x1},{y1} " + " ".join(f"L{px},{py}" for px, py in mid) + f" L{x2},{y2}"
    else:
        path = f"M{x1},{y1} L{x2},{y2}"
    add(f'<path d="{path}" fill="none" stroke="{color}" stroke-width="{sw}"{d}'
        f' marker-end="url(#a-{color[1:]})"{ms}/>')


def badge(x, y, n, color):
    add(f'<circle cx="{x}" cy="{y}" r="10" fill="{color}" stroke="#FFF" stroke-width="1.5"/>')
    text(x, y + 4, str(n), size=11, weight="bold", fill="#FFFFFF", anchor="middle")


# ---------------------------------------------------------------- document
add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
    f'font-family="{FONT}">')
add("<defs>")
for col in {C["line"], C["rep_a"], C["rep_b"], C["cache"], C["mgmt"], C["ink"], C["storage"], C["net"]}:
    add(f'<marker id="a-{col[1:]}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
        f'markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{col}"/></marker>')
add("</defs>")
add(f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>')

# title band
add(f'<rect width="{W}" height="78" fill="{C["ink"]}"/>')
text(30, 36, "Amazon FSx for NetApp ONTAP — Active/Active Cross-Region DR", 26, "bold", "#FFFFFF")
text(30, 62, "Per-dataset write ownership · bidirectional SnapMirror (5-min schedule) · FlexCache global namespace · "
     "Multi-AZ HA in each Region", 14, fill="#D5DBDB")
text(W - 30, 36, "RPO ≤ 5 min  ·  RTO ≤ 15 min", 22, "bold", "#FF9900", "end")
text(W - 30, 62, "AZ failure: automatic, ~60 s, RPO 0", 14, fill="#D5DBDB", anchor="end")

# ---------------------------------------------------------------- global tier
box(300, 98, 250, 92, C["line"])
icon(312, 110, C["muted"], "USR")
lines(354, 122, [("Users / on-prem sites", {"weight": "bold"}),
                 "Site-to-Site VPN or Direct Connect", "to both Regions"])

box(730, 98, 340, 92, C["net"])
icon(742, 110, C["net"], "R53")
lines(784, 122, [("Amazon Route 53", {"weight": "bold"}),
                 "app.example.com · latency-based routing",
                 "HTTPS health check: 10 s interval, threshold 3",
                 "record TTL 60 s · auto-evicts unhealthy Region"], size=11)

box(1250, 98, 300, 92, C["sec"])
icon(1262, 110, C["sec"], "AD")
lines(1304, 122, [("AWS Managed Microsoft AD", {"weight": "bold"}),
                  "multi-Region replication (SMB auth)",
                  "SVM ⇄ DCs: 53, 88, 135, 389, 445, 464,",
                  "636, 3268-3269, 49152-65535"], size=11)

arrow(550, 144, 728, 144, C["line"])


# ---------------------------------------------------------------- one Region
def region(x0, side, cidr, rname, azs, owner, ep, vols, nodes_ip):
    w = 740
    box(x0, 222, w, 708, C["region"], fill="#FFFFFF", dash="6 4", rx=4, sw=2)
    icon(x0, 222, C["region"], "RG", 28)
    text(x0 + 36, 241, rname, 15, "bold", C["region"])
    tag(x0 + w - 190, 229, f"WRITE OWNER: {owner}", C["rep_a"] if side == "A" else C["rep_b"], 178)

    box(x0 + 15, 258, w - 30, 660, C["vpc"], fill="#FFFFFF", rx=4, sw=1.6)
    text(x0 + 27, 276, f"VPC {cidr}.0.0/16", 12.5, "bold", C["vpc"])

    azx = [x0 + 30, x0 + 375]
    for i, ax in enumerate(azx):
        box(ax, 288, 335, 316, C["az"], fill="#FFFFFF", dash="5 4", rx=4)
        text(ax + 10, 305, f"Availability Zone {azs[i]}", 11.5, "bold", C["az"])

    # ALB spanning both AZs
    box(x0 + 200, 314, 340, 40, C["app"], fill="#FBEFFC")
    text(x0 + 370, 338, "Application Load Balancer · HTTPS 443 · cross-zone", 11.5, "bold", C["app"], "middle")

    for i, ax in enumerate(azx):
        n = i + 1
        box(ax + 12, 366, 311, 92, C["region"], fill=C["subnet"], rx=3, sw=1)
        icon(ax + 22, 376, C["compute"], "EC2")
        lines(ax + 64, 388, [(f"Private app subnet {cidr}.{n}.0/24", {"weight": "bold"}),
                             "EC2 / EKS workers (NFS & SMB clients)",
                             "mount svm_" + side.lower() + ":/orders and :/media",
                             "NFSv4.1 TCP 2049 · SMB 3.x TCP 445"], size=11)

        box(ax + 12, 470, 311, 122, C["region"], fill=C["subnet"], rx=3, sw=1)
        icon(ax + 22, 480, C["storage"], "FSx")
        role = "PREFERRED · active" if i == 0 else "STANDBY · passive"
        lines(ax + 64, 492, [(f"FSx subnet {cidr}.1{n}.0/24", {"weight": "bold"}),
                             f"ONTAP node 0{n} — {role}",
                             f"intercluster LIF {cidr}.1{n}.{nodes_ip}  (SnapMirror)",
                             "data/mgmt via floating endpoint IPs"], size=11)
        add(f'<rect x="{ax + 22}" y="{556}" width="290" height="26" rx="3" fill="#FFFFFF" '
            f'stroke="{C["storage"]}" stroke-dasharray="3 2"/>')
        text(ax + 30, 573, "ENI + route-table entry for " + ep, 10.5, fill=C["muted"])

    # HA sync between nodes
    arrow(x0 + 322, 530, x0 + 418, 530, C["storage"], both=True, sw=2)
    text(x0 + 370, 547, "sync HA", 10, "bold", C["storage"], "middle")

    # file system container
    box(x0 + 30, 616, 680, 290, C["storage"], fill=C["storage_bg"], rx=5, sw=1.8)
    icon(x0 + 40, 626, C["storage"], "ONTAP", 40)
    lines(x0 + 90, 640, [(f"Amazon FSx for NetApp ONTAP · fs-{side} · Multi-AZ HA pair (node 01 / 02)",
                          {"weight": "bold"}),
                         "SSD 2 TiB + capacity pool tier · throughput 512 MBps · KMS CMK at rest · "
                         "SMB3/NFS4.1 in-flight encryption"], size=11.5)
    text(x0 + 90, 674, f"Floating endpoints {ep}: management (HTTPS 443, SSH 22) · NFS / SMB / iSCSI data",
         11, fill=C["muted"])

    box(x0 + 45, 686, 650, 208, C["storage"], fill="#FFFFFF", rx=4, sw=1.2)
    text(x0 + 57, 704, f"SVM svm_{side.lower()}  ·  AD-joined (SMB) · export-policy: app subnets of both Regions",
         11.5, "bold", C["storage"])

    ys = []
    for j, (vname, vtype, jpath, desc, colr) in enumerate(vols):
        y = 714 + j * 60
        ys.append(y + 26)
        add(f'<rect x="{x0 + 57}" y="{y}" width="626" height="52" rx="4" fill="#FFFFFF" '
            f'stroke="{colr}" stroke-width="1.6"/>')
        add(f'<rect x="{x0 + 57}" y="{y}" width="6" height="52" rx="2" fill="{colr}"/>')
        text(x0 + 73, y + 20, vname, 12.5, "bold")
        tag(x0 + 245, y + 7, vtype, colr, 112)
        text(x0 + 367, y + 20, f"junction {jpath}", 11.5, "bold", C["muted"])
        text(x0 + 73, y + 40, desc, 11, fill=C["muted"])
    return ys


ya = region(30, "A", "10.10", "Region A · us-east-1 (N. Virginia)", ["use1-az1", "use1-az2"],
            "/orders", "198.19.255.0/24",
            [("vol_orders", "RW · ORIGIN", "/orders", "authoritative copy · snapshot every 5 min → replicated to Region B ①",
              C["rep_a"]),
             ("vol_media_cache", "FLEXCACHE", "/media", "sparse cache of B:vol_media · local reads, writes forwarded to origin ④",
              C["cache"]),
             ("vol_media_dr", "DP · READ-ONLY", "/dr/media", "SnapMirror destination of B:vol_media ② · promoted on Region B loss",
              C["rep_b"])],
            "x")
yb = region(1030, "B", "10.20", "Region B · us-west-2 (Oregon)", ["usw2-az1", "usw2-az2"],
            "/media", "198.19.254.0/24",
            [("vol_orders_dr", "DP · READ-ONLY", "/dr/orders", "SnapMirror destination of A:vol_orders ① · promoted on Region A loss",
              C["rep_a"]),
             ("vol_orders_cache", "FLEXCACHE", "/orders", "sparse cache of A:vol_orders · local reads, writes forwarded to origin ③",
              C["cache"]),
             ("vol_media", "RW · ORIGIN", "/media", "authoritative copy · snapshot every 5 min → replicated to Region A ②",
              C["rep_b"])],
            "x")

# Route 53 → ALBs
arrow(800, 190, 400, 312, C["net"], dash="6 4", sw=1.6, mid=[(800, 207), (400, 207)])
arrow(1000, 190, 1400, 312, C["net"], dash="6 4", sw=1.6, mid=[(1000, 207), (1400, 207)])
text(790, 202, "latency record → ALB Region A", 10.5, "bold", C["net"], "end")
text(1010, 202, "latency record → ALB Region B", 10.5, "bold", C["net"])

# ---------------------------------------------------------------- inter-region middle column
mx0, mx1 = 770, 1030
box(782, 262, 236, 248, C["line"], fill="#F8F9FA", rx=5)
text(900, 282, "Cross-Region data flows", 12.5, "bold", anchor="middle")
flows = [
    (1, C["rep_a"], ["SnapMirror async /orders  A → B", "schedule 5min · MirrorAllSnapshots", "TCP 11104 ctrl · 11105 data"]),
    (2, C["rep_b"], ["SnapMirror async /media  B → A", "schedule 5min · MirrorAllSnapshots", "TCP 11104 ctrl · 11105 data"]),
    (3, C["cache"], ["FlexCache /orders  B ⇄ A origin", "read miss / write-around · 11105"]),
    (4, C["cache"], ["FlexCache /media  A ⇄ B origin", "read miss / write-around · 11105"]),
]
fy = 302
for n, col, rows in flows:
    badge(800, fy + 4, n, col)
    lines(817, fy + 8, [(rows[0], {"weight": "bold"})] + rows[1:], size=10.5, gap=13.5)
    fy += 14 + 13.5 * len(rows)

# TGW peering
for tx in (742, 1002):
    icon(tx, 532, C["net"], "TGW", 56)
arrow(800, 560, 1000, 560, C["net"], both=True, sw=2.4)
lines(900, 546, [("TGW inter-Region peering", {"weight": "bold", "anchor": "middle"})], size=11, fill=C["net"])
lines(900, 580, ["static routes 10.10/16 ⇄ 10.20/16",
                 "AWS backbone · encrypted in transit",
                 "SG: IC LIF ⇄ IC LIF 11104/11105, ICMP",
                 "~65 ms RTT use1 ⇄ usw2"], size=10.5, gap=13.5, fill=C["muted"], anchor="middle")

# replication arrows between volume rows (x: region A card right edge 740 → region B card left 1087)
ax_r, bx_l = 30 + 57 + 626, 1030 + 57
arrow(ax_r, ya[0] - 6, bx_l, yb[0] - 6, C["rep_a"], sw=2.6)                    # ① orders A→B
badge(900, ya[0] - 6, 1, C["rep_a"])
arrow(bx_l, yb[2] + 6, ax_r, ya[2] + 6, C["rep_b"], sw=2.6)                    # ② media B→A
badge(900, ya[2] + 6, 2, C["rep_b"])
arrow(bx_l, yb[1] - 6, ax_r, ya[0] + 8, C["cache"], dash="5 3", both=True, sw=1.8)   # ③ orders cache ⇄ origin
badge(845, (yb[1] - 6 + ya[0] + 8) / 2 + 12, 3, C["cache"])
arrow(ax_r, ya[1] + 6, bx_l, yb[2] - 8, C["cache"], dash="5 3", both=True, sw=1.8)   # ④ media cache ⇄ origin
badge(955, (ya[1] + 6 + yb[2] - 8) / 2 + 12, 4, C["cache"])

# ---------------------------------------------------------------- observability / automation band
box(30, 948, 1740, 200, C["mgmt"], fill="#FDF1F7", rx=5, sw=1.6)
text(44, 970, "Observability & DR automation  (deployed identically in both Regions — each Region watches the "
     "relationships it is the destination for)", 13, "bold", C["mgmt"])

cards = [
    ("EVB", C["mgmt"], "EventBridge Scheduler", ["rate(1 minute)", "invokes lag monitor"]),
    ("λ", C["compute"], "Lambda · lag monitor", ["in VPC, FSx-mgmt SG", "GET /api/snapmirror/", "relationships  (HTTPS 443)"]),
    ("CW", C["mgmt"], "CloudWatch", ["Custom/FSxONTAP", "SnapMirrorLagSeconds", "SnapMirrorHealthy (0/1)"]),
    ("ALM", C["sec"], "Alarms", ["WARN lag > 300 s (1 of 1)", "CRIT lag > 600 s (3 of 3)", "unhealthy = 1 · no data"]),
    ("SNS", C["mgmt"], "SNS → on-call", ["PagerDuty / Slack / email", "runbook link in payload"]),
    ("SSM", C["mgmt"], "SSM Automation", ["DR-Failover-<dataset>", "quiesce → break → remount", "→ scale app → R53 check"]),
]
cx = 44
cw = 230
for i, (g, col, title, rows) in enumerate(cards):
    box(cx, 984, cw, 88, col, rx=4)
    icon(cx + 10, 994, col, g)
    lines(cx + 52, 1006, [(title, {"weight": "bold"})] + rows, size=11, gap=14.5)
    if i < len(cards) - 1:
        arrow(cx + cw, 1028, cx + cw + 22, 1028, C["mgmt"], sw=1.8)
    cx += cw + 23

box(44, 1084, 560, 54, C["sec"], rx=4)
icon(54, 1094, C["sec"], "SM")
lines(96, 1106, [("Secrets Manager", {"weight": "bold"}),
                 "fsxadmin / vsadmin credentials · KMS-encrypted · rotation 30 d · read by Lambda + SSM"], size=11)
box(620, 1084, 560, 54, C["storage"], rx=4)
icon(630, 1094, C["storage"], "BKP")
lines(672, 1106, [("AWS Backup (separate from DR)", {"weight": "bold"}),
                  "daily + cross-Region copy · 35 d · vault lock — protects against ransomware / bad writes"], size=11)
box(1196, 1084, 560, 54, C["muted"], rx=4)
icon(1206, 1094, C["muted"], "SNAP")
lines(1248, 1106, [("ONTAP local snapshots", {"weight": "bold"}),
                   "hourly ×24, daily ×7 on every RW volume · instant file-level restore · SnapLock optional"], size=11)

# ---------------------------------------------------------------- tables
def table(x, y, w, title, cols, rows, widths, col=C["ink"]):
    text(x, y, title, 14, "bold", col)
    y += 10
    add(f'<rect x="{x}" y="{y}" width="{w}" height="22" fill="{C["ink"]}"/>')
    cx = x
    for c, cwid in zip(cols, widths):
        text(cx + 8, y + 15, c, 11, "bold", "#FFFFFF")
        cx += cwid
    y += 22
    for i, r in enumerate(rows):
        add(f'<rect x="{x}" y="{y}" width="{w}" height="20" fill="{"#F3F4F6" if i % 2 else "#FFFFFF"}"/>')
        cx = x
        for k, (cell, cwid) in enumerate(zip(r, widths)):
            text(cx + 8, y + 14, cell, 10.5, "bold" if k == 0 else "normal", C["ink"] if k else C["muted"])
            cx += cwid
        y += 20
    add(f'<rect x="{x}" y="{y - 20 * len(rows) - 22}" width="{w}" height="{20 * len(rows) + 22}" '
        f'fill="none" stroke="#D5DBDB"/>')


table(30, 1178, 760, "Port matrix (Security Groups / NACLs)",
      ["Purpose", "Protocol / port", "Source → Destination"],
      [["Cluster & SVM peering", "ICMP + TCP 11104", "IC LIFs Region A ⇄ IC LIFs Region B"],
       ["SnapMirror / FlexCache data", "TCP 11105", "IC LIFs Region A ⇄ IC LIFs Region B"],
       ["ONTAP REST API / System Mgr", "TCP 443", "Lambda, SSM, admin bastion → mgmt endpoint"],
       ["ONTAP CLI", "TCP 22", "admin bastion → mgmt endpoint"],
       ["NFS v3 / v4.1", "TCP/UDP 111, 635, 2049, 4045-4046, 4049", "app subnets → SVM data endpoint"],
       ["SMB 3.x", "TCP 445", "app subnets / users → SVM data endpoint"],
       ["iSCSI (optional)", "TCP 3260", "app subnets → SVM iSCSI endpoint"],
       ["Active Directory", "53, 88, 123, 135, 389, 445, 464, 636, 3268-9, 49152-65535", "SVM → domain controllers"],
       ["App ingress", "TCP 443", "Route 53 HC / clients → ALB → targets"]],
      [190, 300, 270])

table(810, 1178, 560, "Timing budget (RPO / RTO)",
      ["Stage", "Value"],
      [["SnapMirror schedule (RPO driver)", "every 5 min (ONTAP 5min cron)"],
       ["Lag poll → metric", "60 s"],
       ["Lag alarm WARN / CRIT", "> 300 s / > 600 s"],
       ["AZ failover inside a Region", "automatic · ~60 s · RPO 0"],
       ["Region outage detection", "R53 10 s × 3 = 30 s · CW alarm ≤ 3 min"],
       ["Failover decision (human-approved)", "≤ 5 min"],
       ["snapmirror break + junction remount", "1-2 min (SSM Automation)"],
       ["Client DNS convergence", "TTL 60 s"],
       ["Regional RTO / RPO target", "≤ 15 min  /  ≤ 5 min + last transfer"]],
      [270, 290])

text(1390, 1178, "Legend", 14, "bold")
leg = [(C["rep_a"], None, "SnapMirror A → B (/orders)"),
       (C["rep_b"], None, "SnapMirror B → A (/media)"),
       (C["cache"], "5 3", "FlexCache origin ⇄ cache"),
       (C["storage"], None, "Multi-AZ HA sync (in-Region)"),
       (C["net"], None, "TGW peering / DNS routing")]
ly = 1202
for col, dash, lbl in leg:
    arrow(1392, ly, 1440, ly, col, dash=dash, sw=2.2)
    text(1452, ly + 4, lbl, 11)
    ly += 24
for dash, col, lbl in [("6 4", C["region"], "AWS Region"), (None, C["vpc"], "VPC"),
                       ("5 4", C["az"], "Availability Zone")]:
    box(1392, ly - 8, 48, 16, col, dash=dash, rx=2)
    text(1452, ly + 4, lbl, 11)
    ly += 24
text(1390, ly + 8, "IPs are illustrative; FSx assigns LIF IPs.", 10.5, fill=C["muted"], italic=True)

text(30, H - 16, "cloud-architecture-lab · 01-fsx-ontap-active-active-dr · design + POC, validate "
     "against current AWS & NetApp docs before production", 11, fill=C["muted"])
add("</svg>")

Path(__file__).with_name("architecture.svg").write_text("\n".join(out), encoding="utf-8")
print("wrote architecture.svg")
