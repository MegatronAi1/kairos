"""Ship the current commit to the hosted demo without changing its URL (blue/green).

Usage: uv run python infra/update.py [profile]

Uploads a fresh source + runtime bundle, launches a new instance with the same
token, waits for its health check (temporarily allowing this machine's IP),
points CloudFront at it, then terminates the old instance. Runtime data on the
old instance (var/feedback.jsonl) is not migrated.
"""

from __future__ import annotations

import time
import urllib.request

import deploy as d


def my_ip() -> str:
    with urllib.request.urlopen("https://checkip.amazonaws.com", timeout=10) as r:
        return r.read().decode().strip()


def wait_healthy(dns: str, timeout_s: int = 900) -> None:
    url = f"http://{dns}:8080/api/v1/healthz"
    start = time.time()
    # Count attempts, not wall time: a laptop that sleeps mid-wait must not time out.
    for _ in range(timeout_s // 15):
        try:
            with urllib.request.urlopen(url, timeout=5) as r:
                if r.status == 200:
                    return
        except Exception:
            pass
        time.sleep(15)
        d.log(f"waiting for {url} ({int(time.time() - start)} s)")
    raise SystemExit("new instance did not become healthy; old instance left serving")


def point_cloudfront(dns: str) -> None:
    did = str(d.state["distribution_id"])
    res = d.cf.get_distribution_config(Id=did)
    cfg, etag = res["DistributionConfig"], res["ETag"]
    cfg["Origins"]["Items"][0]["DomainName"] = dns
    d.cf.update_distribution(Id=did, DistributionConfig=cfg, IfMatch=etag)
    d.log("CloudFront origin updated; waiting for the change to deploy")
    d.cf.get_waiter("distribution_deployed").wait(Id=did)


def main() -> None:
    old = d.state.get("instance_id")
    if not old or not d.state.get("distribution_id"):
        raise SystemExit("nothing deployed yet: run infra/deploy.py")
    src, runtime = d.package()
    b = d.bucket(src, runtime)
    prof = d.instance_profile(b)
    sg = d.security_group()
    ip = f"{my_ip()}/32"
    rule = [{"IpProtocol": "tcp", "FromPort": 8080, "ToPort": 8080, "IpRanges": [{"CidrIp": ip, "Description": "update health check"}]}]
    try:
        d.ec2.authorize_security_group_ingress(GroupId=sg, IpPermissions=rule)
    except d.ClientError:
        pass  # already allowed
    try:
        d.state.pop("instance_id")
        iid = d.instance(sg, prof, d.user_data(b, str(d.state["token"]), use_role=prof is not None))
        dns = d.ec2.describe_instances(InstanceIds=[iid])["Reservations"][0]["Instances"][0]["PublicDnsName"]
        d.log(f"new origin {dns}; building (about 6-8 min)")
        wait_healthy(dns)
        point_cloudfront(dns)
    except BaseException:
        d.state["instance_id"] = old  # keep serving from the old instance
        d.save()
        raise
    finally:
        d.ec2.revoke_security_group_ingress(GroupId=sg, IpPermissions=rule)
    d.ec2.terminate_instances(InstanceIds=[str(old)])
    d.log(f"terminated old instance {old}; live at {d.state.get('url')}")


if __name__ == "__main__":
    main()
