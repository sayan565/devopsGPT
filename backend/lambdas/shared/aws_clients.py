"""Shared AWS client factory."""
import boto3
import os
from functools import lru_cache

MASTER_REGION = os.environ.get("AWS_REGION", "us-east-1")

TENANT_ROLES = {
    # Add tenant role ARNs here when onboarding tenants
    # "tenant123": "arn:aws:iam::123456789:role/DevOpsGPTRole"
}

def get_tenant_role(tenant_id: str):
    return TENANT_ROLES.get(tenant_id)

def get_client(service: str, tenant_role_arn: str = None, region: str = None):
    region = region or MASTER_REGION
    if tenant_role_arn:
        sts = boto3.client("sts")
        creds = sts.assume_role(
            RoleArn=tenant_role_arn,
            RoleSessionName="DevOpsGPTSession",
            DurationSeconds=900,
        )["Credentials"]
        return boto3.client(
            service,
            region_name=region,
            aws_access_key_id=creds["AccessKeyId"],
            aws_secret_access_key=creds["SecretAccessKey"],
            aws_session_token=creds["SessionToken"],
        )
    return boto3.client(service, region_name=region)