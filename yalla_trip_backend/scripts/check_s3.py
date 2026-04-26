"""Quick S3 sanity check — list recent uploads + clean smoke test object."""
import boto3
import os
from botocore.exceptions import ClientError

c = boto3.client(
    "s3",
    aws_access_key_id=os.environ["AWS_ACCESS_KEY"],
    aws_secret_access_key=os.environ["AWS_SECRET_KEY"],
    region_name=os.environ["AWS_REGION"],
)
b = os.environ["AWS_BUCKET_NAME"]

r = c.list_objects_v2(Bucket=b, Prefix="properties/", MaxKeys=20)
print("=== Files in S3 (properties/) ===")
print("Total objects:", r.get("KeyCount", 0))
for obj in sorted(r.get("Contents", []), key=lambda x: x["LastModified"], reverse=True)[:8]:
    ts = obj["LastModified"].strftime("%Y-%m-%d %H:%M")
    size = obj["Size"]
    key = obj["Key"]
    print("  " + ts + " | " + str(size).rjust(6) + " B | " + key)

try:
    c.delete_object(
        Bucket=b,
        Key="properties/9999_smoke/dcab9513dd8c4938b410998134053a57.jpg",
    )
    print("\n[OK] Smoke test object cleaned up")
except ClientError as e:
    print("Cleanup skipped:", e.response["Error"]["Code"])
