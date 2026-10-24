"""Deploy Kairos to AWS (us-east-1): S3 (private) + EC2 (docker compose) + CloudFront (HTTPS/WSS).

Usage:  uv run python infra/deploy.py            (uses AWS profile `kairos`)
        uv run python infra/teardown.py          (removes everything this created)

What it creates (all tagged project=kairos):
- private S3 bucket kairos-deploy-<account> with the source tarball and the 10 MB of
  runtime data/model artifacts (Block Public Access on)
- IAM role + instance profile for the EC2 box (S3 read, Bedrock invoke) when the
  account allows it; no long-lived keys on the box
- security group allowing port 8080 only from CloudFront's origin-facing prefix list
- one EC2 instance (Amazon Linux 2023, t3.large, 30 GB) running `docker compose up`
- a CloudFront distribution in front (HTTPS + WebSockets, caching disabled)

State is written to infra/.deploy-state.json (gitignored) for teardown.
"""

from __future__ import annotations

import io
import json
import secrets
import subprocess
import sys
import tarfile
import time
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / "infra" / ".deploy-state.json"
REGION = "us-east-1"
PROFILE = sys.argv[1] if len(sys.argv) > 1 else "kairos"
TAG = [{"Key": "project", "Value": "kairos"}]
MODEL_CHAT = "us.anthropic.claude-sonnet-5"
MODEL_FAST = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
CACHING_DISABLED = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # AWS managed cache policy
ALL_VIEWER = "216adef6-5c7f-47e4-b989-5492eafa07d3"  # AWS managed origin request policy

session = boto3.Session(profile_name=PROFILE, region_name=REGION)
account = session.client("sts").get_caller_identity()["Account"]
s3, ec2, iam, cf, ssm = (session.client(n) for n in ("s3", "ec2", "iam", "cloudfront", "ssm"))
state: dict[str, object] = json.loads(STATE.read_text()) if STATE.exists() else {}


def save() -> None:
    STATE.write_text(json.dumps(state, indent=2))


def log(msg: str) -> None:
    print(f"[deploy] {msg}", flush=True)


# --- 1. package -----------------------------------------------------------------
def package() -> tuple[bytes, bytes]:
    src = subprocess.run(["git", "archive", "--format=tar.gz", "HEAD"], cwd=ROOT, check=True, capture_output=True).stdout
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for rel in [
            "data/processed/indpensim_process.parquet",
            "artifacts/models/kairos.joblib",
            "data/raw/archive/Mendeley_data/100_Batches_IndPenSim_Statistics.csv",
        ]:
            if (ROOT / rel).exists():
                tar.add(ROOT / rel, arcname=rel)
    return src, buf.getvalue()


# --- 2. bucket ------------------------------------------------------------------
def bucket(src: bytes, runtime: bytes) -> str:
    name = f"kairos-deploy-{account}"
    try:
        s3.create_bucket(Bucket=name)
        log(f"created bucket {name}")
    except ClientError as e:
        if e.response["Error"]["Code"] not in ("BucketAlreadyOwnedByYou", "BucketAlreadyExists"):
            raise
    s3.put_public_access_block(
        Bucket=name,
        PublicAccessBlockConfiguration={k: True for k in ("BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets")},
    )
    s3.put_object(Bucket=name, Key="kairos-src.tar.gz", Body=src)
    s3.put_object(Bucket=name, Key="kairos-runtime.tar.gz", Body=runtime)
    log(f"uploaded source ({len(src) // 1024} KB) and runtime artifacts ({len(runtime) // 1024} KB)")
    state["bucket"] = name
    save()
    return name


# --- 3. instance role (optional) ------------------------------------------------
def instance_profile(bucket_name: str) -> str | None:
    role, prof = "kairos-ec2-role", "kairos-ec2-profile"
    try:
        try:
            iam.create_role(
                RoleName=role,
                AssumeRolePolicyDocument=json.dumps(
                    {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"Service": "ec2.amazonaws.com"}, "Action": "sts:AssumeRole"}]}
                ),
                Tags=TAG,
            )
        except ClientError as e:
            if e.response["Error"]["Code"] != "EntityAlreadyExists":
                raise
        iam.put_role_policy(
            RoleName=role,
            PolicyName="kairos-runtime",
            PolicyDocument=json.dumps(
                {
                    "Version": "2012-10-17",
                    "Statement": [
                        {"Effect": "Allow", "Action": ["s3:GetObject"], "Resource": f"arn:aws:s3:::{bucket_name}/*"},
                        {"Effect": "Allow", "Action": ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:Converse", "bedrock:ConverseStream"], "Resource": "*"},
                    ],
                }
            ),
        )
        try:
            iam.create_instance_profile(InstanceProfileName=prof, Tags=TAG)
            iam.add_role_to_instance_profile(InstanceProfileName=prof, RoleName=role)
            time.sleep(12)  # IAM propagation
        except ClientError as e:
            if e.response["Error"]["Code"] != "EntityAlreadyExists":
                raise
        state["role"], state["profile"] = role, prof
        save()
        log("instance role ready (S3 read + Bedrock, no keys on the box)")
        return prof
    except ClientError as e:
        log(f"cannot create IAM role ({e.response['Error']['Code']}); falling back to presigned downloads")
        return None


# --- 4. network -----------------------------------------------------------------
def security_group() -> str:
    vpc = ec2.describe_vpcs(Filters=[{"Name": "isDefault", "Values": ["true"]}])["Vpcs"] or ec2.describe_vpcs()["Vpcs"]
    vpc_id = vpc[0]["VpcId"]
    existing = ec2.describe_security_groups(Filters=[{"Name": "group-name", "Values": ["kairos-web"]}, {"Name": "vpc-id", "Values": [vpc_id]}])["SecurityGroups"]
    if existing:
        sg = existing[0]["GroupId"]
    else:
        sg = ec2.create_security_group(GroupName="kairos-web", Description="Kairos web via CloudFront only", VpcId=vpc_id)["GroupId"]
        pl = ec2.describe_managed_prefix_lists(Filters=[{"Name": "prefix-list-name", "Values": ["com.amazonaws.global.cloudfront.origin-facing"]}])["PrefixLists"]
        perm = {"IpProtocol": "tcp", "FromPort": 8080, "ToPort": 8080}
        if pl:
            perm["PrefixListIds"] = [{"PrefixListId": pl[0]["PrefixListId"], "Description": "CloudFront origin-facing"}]
        else:
            perm["IpRanges"] = [{"CidrIp": "0.0.0.0/0"}]
        ec2.authorize_security_group_ingress(GroupId=sg, IpPermissions=[perm])
    state["security_group"] = sg
    save()
    return sg


# --- 5. instance ----------------------------------------------------------------
def user_data(bucket_name: str, token: str, use_role: bool) -> str:
    if use_role:
        fetch = f"aws s3 cp s3://{bucket_name}/kairos-src.tar.gz src.tgz && aws s3 cp s3://{bucket_name}/kairos-runtime.tar.gz rt.tgz"
        creds = ""
    else:
        url = lambda k: s3.generate_presigned_url("get_object", Params={"Bucket": bucket_name, "Key": k}, ExpiresIn=3600)  # noqa: E731
        fetch = f"curl -fsSL -o src.tgz '{url('kairos-src.tar.gz')}' && curl -fsSL -o rt.tgz '{url('kairos-runtime.tar.gz')}'"
        c = session.get_credentials().get_frozen_credentials()
        # Temporary workshop credentials (expire); the copilot falls back to rule-based cards afterwards.
        creds = f"AWS_ACCESS_KEY_ID={c.access_key}\nAWS_SECRET_ACCESS_KEY={c.secret_key}\nAWS_SESSION_TOKEN={c.token}\n"
    return f"""#!/bin/bash
set -euxo pipefail
dnf install -y docker tar gzip
systemctl enable --now docker
mkdir -p /usr/local/lib/docker/cli-plugins /root/.aws
curl -fsSL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
mkdir -p /opt/kairos && cd /opt/kairos
{fetch}
tar xzf src.tgz && tar xzf rt.tgz
cat > .env <<'ENV'
AWS_REGION=us-east-1
{creds}KAIROS_MODEL_CHAT={MODEL_CHAT}
KAIROS_MODEL_FAST={MODEL_FAST}
KAIROS_API_TOKEN={token}
ENV
export USERPROFILE=/root
docker compose up -d --build
"""


def instance(sg: str, profile: str | None, ud: str) -> str:
    if state.get("instance_id"):
        log(f"reusing instance {state['instance_id']} (run teardown for a fresh one)")
        return str(state["instance_id"])
    ami = ssm.get_parameter(Name="/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64")["Parameter"]["Value"]
    args: dict[str, object] = dict(
        ImageId=ami,
        InstanceType="t3.large",
        MinCount=1,
        MaxCount=1,
        SecurityGroupIds=[sg],
        UserData=ud,
        BlockDeviceMappings=[{"DeviceName": "/dev/xvda", "Ebs": {"VolumeSize": 30, "VolumeType": "gp3"}}],
        TagSpecifications=[{"ResourceType": "instance", "Tags": TAG + [{"Key": "Name", "Value": "kairos"}]}],
        MetadataOptions={"HttpTokens": "required"},
    )
    if profile:
        args["IamInstanceProfile"] = {"Name": profile}
    iid = ec2.run_instances(**args)["Instances"][0]["InstanceId"]
    state["instance_id"] = iid
    save()
    log(f"launched {iid}; waiting for it to run")
    ec2.get_waiter("instance_running").wait(InstanceIds=[iid])
    return iid


# --- 6. CloudFront --------------------------------------------------------------
def distribution(origin_dns: str) -> str:
    if state.get("distribution_id"):
        d = cf.get_distribution(Id=str(state["distribution_id"]))["Distribution"]
        return str(d["DomainName"])
    ref = f"kairos-{int(time.time())}"
    d = cf.create_distribution(
        DistributionConfig={
            "CallerReference": ref,
            "Comment": "Kairos (hackathon demo)",
            "Enabled": True,
            "Origins": {
                "Quantity": 1,
                "Items": [
                    {
                        "Id": "kairos-ec2",
                        "DomainName": origin_dns,
                        "CustomOriginConfig": {
                            "HTTPPort": 8080,
                            "HTTPSPort": 443,
                            "OriginProtocolPolicy": "http-only",
                            "OriginReadTimeout": 60,
                            "OriginKeepaliveTimeout": 60,
                        },
                    }
                ],
            },
            "DefaultCacheBehavior": {
                "TargetOriginId": "kairos-ec2",
                "ViewerProtocolPolicy": "redirect-to-https",
                "AllowedMethods": {
                    "Quantity": 7,
                    "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
                    "CachedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"]},
                },
                "CachePolicyId": CACHING_DISABLED,
                "OriginRequestPolicyId": ALL_VIEWER,
                "Compress": True,
            },
            "PriceClass": "PriceClass_All",
        }
    )["Distribution"]
    state["distribution_id"] = d["Id"]
    save()
    return str(d["DomainName"])


def main() -> None:
    src, runtime = package()
    b = bucket(src, runtime)
    prof = instance_profile(b)
    sg = security_group()
    token = str(state.get("token") or secrets.token_urlsafe(24))
    state["token"] = token
    save()
    iid = instance(sg, prof, user_data(b, token, use_role=prof is not None))
    dns = ec2.describe_instances(InstanceIds=[iid])["Reservations"][0]["Instances"][0]["PublicDnsName"]
    log(f"origin {dns}")
    domain = distribution(dns)
    state["url"] = f"https://{domain}"
    save()
    log(f"CloudFront: https://{domain} (takes ~5-10 min to deploy; the app needs ~6-8 min to build on first boot)")


if __name__ == "__main__":
    main()
