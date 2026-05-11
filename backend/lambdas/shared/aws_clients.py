"""Shared AWS client factory with DynamoDB-backed tenant role lookup."""
import boto3
import os

MASTER_REGION  = os.environ.get("AWS_REGION", "us-east-1")
TENANTS_TABLE  = os.environ.get("TENANTS_TABLE", "devopsgpt-tenants")

# In-memory cache so we don't hit DynamoDB on every Lambda invocation
_role_cache: dict[str, str | None] = {}


def get_tenant_role(tenant_id: str) -> str | None:
    """
    Look up the IAM role ARN for a tenant from DynamoDB.
    Returns None if not found or ARN is still 'pending'.
    """
    if not tenant_id:
        return None

    # Return cached value if available
    if tenant_id in _role_cache:
        return _role_cache[tenant_id]

    try:
        dynamodb = boto3.client("dynamodb", region_name=MASTER_REGION)
        resp = dynamodb.get_item(
            TableName=TENANTS_TABLE,
            Key={"tenant_id": {"S": tenant_id}},
            ProjectionExpression="role_arn",
        )
        item     = resp.get("Item", {})
        role_arn = item.get("role_arn", {}).get("S", "")

        # Treat 'pending' or empty as no role
        result = role_arn if (role_arn and role_arn != "pending") else None
        _role_cache[tenant_id] = result
        print(f"[aws_clients] tenant={tenant_id} role_arn={result}")
        return result

    except Exception as e:
        print(f"[aws_clients] get_tenant_role error: {e}")
        return None


def get_client(service: str, tenant_role_arn: str = None, region: str = None, tenant_id: str = None):
    """
    Return a boto3 client.
    If tenant_role_arn is provided, assumes that cross-account role first.
    """
    region = region or MASTER_REGION

    if tenant_role_arn:
        try:
            sts   = boto3.client("sts", region_name=MASTER_REGION)
            assume_kwargs = {
                "RoleArn":         tenant_role_arn,
                "RoleSessionName": "DevOpsGPTSession",
                "DurationSeconds": 900,
            }
            # Pass tenant_id as ExternalId if available (matches trust policy condition)
            if tenant_id:
                assume_kwargs["ExternalId"] = tenant_id

            creds = sts.assume_role(**assume_kwargs)["Credentials"]
            return boto3.client(
                service,
                region_name=region,
                aws_access_key_id=creds["AccessKeyId"],
                aws_secret_access_key=creds["SecretAccessKey"],
                aws_session_token=creds["SessionToken"],
            )
        except Exception as e:
            print(f"[aws_clients] assume_role failed for {tenant_role_arn}: {e}")
            # Fall through to master account client

    return boto3.client(service, region_name=region)
