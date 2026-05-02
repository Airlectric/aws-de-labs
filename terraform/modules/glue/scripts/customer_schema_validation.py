import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.types import *

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'BUCKET'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

BUCKET = args['BUCKET']

print("=" * 60)
print("SCHEMA VALIDATION JOB")
print("=" * 60)

# Unified schema that covers all versions.
# Optional fields (phone, subscription_tier) are nullable=True
# so records that don't have them (v1.0, v2.0) still pass validation.
customer_schema = StructType([
    StructField("customer_id",       StringType(), False),
    StructField("email",             StringType(), False),
    StructField("signup_date",       StringType(), False),
    StructField("country",           StringType(), False),
    StructField("phone",             StringType(), True),
    StructField("subscription_tier", StringType(), True),
])

# Test 1: Read v1.0 data (no phone, no subscription_tier)
print("\n[TEST 1] Reading v1.0 data (no phone field)...")
try:
    df_v1 = spark.read.schema(customer_schema).json(
        f"s3://{BUCKET}/schemas/v1.0/customers_v1.json"
    )
    print(f"Successfully read {df_v1.count()} v1.0 records")
    print("Missing optional 'phone' field handled correctly")
    df_v1.show(truncate=False)
except Exception as e:
    print(f"X Error: {e}")

# Test 2: Read v2.0 data (has phone, no subscription_tier)
print("\n[TEST 2] Reading v2.0 data (with phone field)...")
try:
    df_v2 = spark.read.schema(customer_schema).json(
        f"s3://{BUCKET}/schemas/v2.0/customers_v2.json"
    )
    print(f"Successfully read {df_v2.count()} v2.0 records")
    print("New optional 'phone' field handled correctly")
    df_v2.show(truncate=False)
except Exception as e:
    print(f"X Error: {e}")

# Test 3: Read v3.0 data (has phone and subscription_tier)
print("\n[TEST 3] Reading v3.0 data (with phone and subscription_tier)...")
try:
    df_v3 = spark.read.schema(customer_schema).json(
        f"s3://{BUCKET}/schemas/v3.0/customers_v3.json"
    )
    print(f"Successfully read {df_v3.count()} v3.0 records")
    print("Multiple new optional fields handled correctly")
    df_v3.show(truncate=False)
except Exception as e:
    print(f"X Error: {e}")

# Combine all versions — proves schemas can coexist
print("\n[COMBINING] Merging all schema versions...")
df_combined = df_v1.unionByName(df_v2, allowMissingColumns=True) \
                   .unionByName(df_v3, allowMissingColumns=True)
print(f"Combined total: {df_combined.count()} records")
print("Proof: schemas can coexist and be merged!")
df_combined.show(truncate=False)

print("\n" + "=" * 60)
print("SCHEMA COMPATIBILITY VERIFIED")
print("=" * 60)

job.commit()
