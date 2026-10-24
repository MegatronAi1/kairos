"""Remove everything infra/deploy.py created. Usage: uv run python infra/teardown.py"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

STATE = Path(__file__).resolve().parent / ".deploy-state.json"
PROFILE = sys.argv[1] if len(sys.argv) > 1 else "kairos"
s = boto3.Session(profile_name=PROFILE, region_name="us-east-1")
ec2, s3, iam, cf = (s.client(n) for n in ("ec2", "s3", "iam", "cloudfront"))
state = json.loads(STATE.read_text()) if STATE.exists() else {}


def quiet(fn, *a, **k):  # type: ignore[no-untyped-def]
    try:
        return fn(*a, **k)
    except ClientError as e:
        print("  skip:", e.response["Error"]["Code"])
        return None


if did := state.get("distribution_id"):
    d = cf.get_distribution_config(Id=did)
    cfg, etag = d["DistributionConfig"], d["ETag"]
    if cfg["Enabled"]:
        cfg["Enabled"] = False
        etag = cf.update_distribution(Id=did, DistributionConfig=cfg, IfMatch=etag)["ETag"]
        print("disabling CloudFront (can take ~10 min)...")
        cf.get_waiter("distribution_deployed").wait(Id=did)
        etag = cf.get_distribution_config(Id=did)["ETag"]
    quiet(cf.delete_distribution, Id=did, IfMatch=etag)
if iid := state.get("instance_id"):
    quiet(ec2.terminate_instances, InstanceIds=[iid])
    ec2.get_waiter("instance_terminated").wait(InstanceIds=[iid])
if sg := state.get("security_group"):
    time.sleep(5)
    quiet(ec2.delete_security_group, GroupId=sg)
if prof := state.get("profile"):
    quiet(iam.remove_role_from_instance_profile, InstanceProfileName=prof, RoleName=state["role"])
    quiet(iam.delete_instance_profile, InstanceProfileName=prof)
if role := state.get("role"):
    quiet(iam.delete_role_policy, RoleName=role, PolicyName="kairos-runtime")
    quiet(iam.delete_role, RoleName=role)
if b := state.get("bucket"):
    for obj in s3.list_objects_v2(Bucket=b).get("Contents", []):
        s3.delete_object(Bucket=b, Key=obj["Key"])
    quiet(s3.delete_bucket, Bucket=b)
STATE.unlink(missing_ok=True)
print("teardown complete")
