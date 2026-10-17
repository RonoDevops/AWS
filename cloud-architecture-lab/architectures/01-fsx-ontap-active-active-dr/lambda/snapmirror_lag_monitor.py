"""SnapMirror lag monitor for Amazon FSx for NetApp ONTAP.

Runs every minute in the destination Region. Reads every SnapMirror relationship whose
destination is on this cluster from the ONTAP REST API and publishes, per destination path:

  Custom/FSxONTAP  SnapMirrorLagSeconds  {Cluster, Destination}
  Custom/FSxONTAP  SnapMirrorHealthy     {Cluster, Destination}   1 = healthy, 0 = not

lag_time is the age of the newest common snapshot, i.e. the data you would lose if the
source Region disappeared right now -- the live RPO.
"""
import base64
import json
import os
import re
import ssl
import urllib.request

import boto3

ONTAP_HOST = os.environ["ONTAP_HOST"]
SECRET_ARN = os.environ["SECRET_ARN"]
NAMESPACE = os.environ.get("NAMESPACE", "Custom/FSxONTAP")
CLUSTER = os.environ.get("CLUSTER", ONTAP_HOST)
VERIFY_TLS = os.environ.get("VERIFY_TLS", "true").lower() == "true"

_secrets = boto3.client("secretsmanager")
_cloudwatch = boto3.client("cloudwatch")
_auth_header = None

_DURATION = re.compile(r"^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$")


def iso8601_seconds(value):
    """'P1DT2H3M4S' -> 93784.0  (ONTAP reports lag_time as an ISO-8601 duration)."""
    m = _DURATION.match(value or "")
    if not m:
        raise ValueError(f"unexpected duration {value!r}")
    d, h, mi, s = (float(x) if x else 0.0 for x in m.groups())
    return d * 86400 + h * 3600 + mi * 60 + s


def _auth():
    global _auth_header
    if _auth_header is None:
        secret = json.loads(_secrets.get_secret_value(SecretId=SECRET_ARN)["SecretString"])
        token = base64.b64encode(f"{secret['username']}:{secret['password']}".encode()).decode()
        _auth_header = f"Basic {token}"
    return _auth_header


def fetch_relationships():
    url = (f"https://{ONTAP_HOST}/api/snapmirror/relationships"
           "?fields=source.path,destination.path,state,healthy,lag_time,unhealthy_reason"
           "&return_records=true&max_records=1000")
    req = urllib.request.Request(url, headers={"Authorization": _auth(), "Accept": "application/json"})
    ctx = ssl.create_default_context()
    if not VERIFY_TLS:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        return json.load(resp).get("records", [])


def handler(event, context):
    metrics, report = [], []
    for rel in fetch_relationships():
        dest = rel.get("destination", {}).get("path")
        if not dest:
            continue
        dims = [{"Name": "Cluster", "Value": CLUSTER}, {"Name": "Destination", "Value": dest}]
        healthy = 1 if rel.get("healthy") else 0
        metrics.append({"MetricName": "SnapMirrorHealthy", "Dimensions": dims, "Value": healthy, "Unit": "Count"})

        lag = None
        if rel.get("lag_time"):
            lag = iso8601_seconds(rel["lag_time"])
            metrics.append({"MetricName": "SnapMirrorLagSeconds", "Dimensions": dims, "Value": lag, "Unit": "Seconds"})
        # No lag_time (e.g. uninitialized or broken-off) -> no lag datapoint -> alarm treats as breaching.

        report.append({"source": rel.get("source", {}).get("path"), "destination": dest,
                       "state": rel.get("state"), "healthy": bool(healthy), "lag_seconds": lag,
                       "unhealthy_reason": rel.get("unhealthy_reason")})

    for i in range(0, len(metrics), 1000):
        _cloudwatch.put_metric_data(Namespace=NAMESPACE, MetricData=metrics[i:i + 1000])

    print(json.dumps({"cluster": CLUSTER, "relationships": report}))
    return {"relationships": len(report)}
