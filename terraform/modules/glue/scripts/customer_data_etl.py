import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *

# Initialize Glue
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'BUCKET'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

BUCKET_NAME = args['BUCKET']
RAW_PATH = f"s3://{BUCKET_NAME}/raw/customers/"
PROCESSED_PATH = f"s3://{BUCKET_NAME}/processed/customers/"

print("=" * 60)
print("CUSTOMER DATA ETL JOB")
print("=" * 60)

try:
    # ===== EXTRACT =====
    print("\n[1/3] EXTRACT: Reading raw customer data...")
    df = spark.read.csv(
        RAW_PATH,
        header=True,
        inferSchema=True
    )
    initial_count = df.count()
    print(f"√ Rows read: {initial_count}")

    # ===== TRANSFORM =====
    print("\n[2/3] TRANSFORM: Cleaning and enriching data...")

    # 1. Remove duplicates (keep first occurrence)
    df_deduped = df.dropDuplicates(["customer_id"])
    dedupe_count = df_deduped.count()
    duplicates_removed = initial_count - dedupe_count
    print(f"√ Duplicates removed: {duplicates_removed}")
    print(f"√ Rows after deduplication: {dedupe_count}")

    # 2. Standardize columns
    df_clean = df_deduped.withColumn(
        "email", lower(col("email"))          # lowercase emails
    ).withColumn(
        "country", upper(col("country"))      # uppercase countries
    ).withColumn(
        "status", coalesce(col("status"), lit("unknown"))  # fill nulls
    )

    # 3. Parse signup_date to consistent format
    df_clean = df_clean.withColumn(
        "signup_date", to_date(col("signup_date"), "yyyy-MM-dd")
    )

    # 4. Add metadata columns
    df_clean = df_clean.withColumn(
        "processed_at", current_timestamp()
    ).withColumn(
        "data_quality_score", lit(0.95)
    )

    print("√ Standardization complete")
    print("√ Metadata columns added")

    # ===== LOAD =====
    print("\n[3/3] LOAD: Writing processed data to S3...")

    df_clean.write.mode("overwrite").parquet(PROCESSED_PATH)

    final_count = df_clean.count()
    print(f"√ Rows written: {final_count}")
    print(f"√ Output path: {PROCESSED_PATH}")

    print("\n" + "=" * 60)
    print("SAMPLE OF TRANSFORMED DATA (first 5 rows)")
    print("=" * 60)
    df_clean.show(5, truncate=False)

    print("\n" + "=" * 60)
    print("JOB COMPLETED SUCCESSFULLY √")
    print("=" * 60)

except Exception as e:
    print(f"\n ERROR: {str(e)}")
    print("Check CloudWatch logs for details")
    raise

finally:
    job.commit()
