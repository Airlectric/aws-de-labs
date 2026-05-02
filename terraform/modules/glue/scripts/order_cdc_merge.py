import sys
import traceback
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.functions import *

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'BUCKET'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

BUCKET = args['BUCKET']
BASE_PATH = f"s3://{BUCKET}/cdc/orders"

print("=" * 70)
print("ORDER CDC MERGE JOB - Apply changes to master table")
print("=" * 70)

try:
    # ===== STEP 1: Load source data =====
    print("\n[STEP 1] Loading initial source data...")
    df_source = spark.read.csv(
        f"{BASE_PATH}/source/source_orders.csv",
        header=True,
        inferSchema=True
    )
    source_count = df_source.count()
    print(f"Loaded {source_count} source records")
    print("Sample data:")
    df_source.show(3)

    # Start with source as master
    df_master = df_source.select(
        "order_id", "customer_id", "order_date", "total_amount", "status"
    )

    # ===== STEP 2: Load CDC changes =====
    print("\n[STEP 2] Loading CDC change files...")

    # Load all CDC files from changes/ folder in one read
    df_cdc = spark.read.csv(
        f"{BASE_PATH}/changes/*.csv",
        header=True,
        inferSchema=True
    )
    cdc_count = df_cdc.count()
    print(f"Loaded {cdc_count} CDC change records")

    # Separate by operation type
    df_insert = df_cdc.filter(col("operation") == "I").select(
        "order_id", "customer_id", "order_date", "total_amount", "status"
    )
    df_update = df_cdc.filter(col("operation") == "U").select(
        "order_id", "customer_id", "order_date", "total_amount", "status"
    )
    df_delete = df_cdc.filter(col("operation") == "D").select("order_id")

    insert_count = df_insert.count()
    update_count = df_update.count()
    delete_count = df_delete.count()

    print(f"  - INSERT: {insert_count} records")
    print(f"  - UPDATE: {update_count} records")
    print(f"  - DELETE: {delete_count} records")

    # ===== STEP 3: Apply INSERT =====
    print("\n[STEP 3] Applying INSERT operations...")
    df_master = df_master.unionByName(df_insert)
    master_count = df_master.count()
    print(f"After INSERT: {master_count} total records")

    # ===== STEP 4: Apply UPDATE =====
    # left_anti join removes any master rows whose order_id appears in the
    # update set, then we union in the new (updated) versions of those rows.
    print("\n[STEP 4] Applying UPDATE operations...")
    if update_count > 0:
        df_master = df_master.join(
            df_update.select("order_id").distinct(),
            on="order_id",
            how="left_anti"
        )
        df_master = df_master.unionByName(df_update)
        master_count = df_master.count()
        print(f"After UPDATE: {master_count} total records")
    else:
        print("No UPDATE records")

    # ===== STEP 5: Apply DELETE =====
    # left_anti join removes any master rows whose order_id appears in the
    # delete set — those rows are gone from the final dataset.
    print("\n[STEP 5] Applying DELETE operations...")
    if delete_count > 0:
        df_master = df_master.join(
            df_delete.select("order_id").distinct(),
            on="order_id",
            how="left_anti"
        )
        master_count = df_master.count()
        print(f"After DELETE: {master_count} total records")
    else:
        print("No DELETE records")

    # ===== STEP 6: Verify data quality =====
    print("\n[STEP 6] Verifying data quality...")

    df_deduped = df_master.dropDuplicates(["order_id"])
    dedup_count = df_deduped.count()

    if dedup_count == master_count:
        print(f"No duplicates found ({master_count} unique orders)")
    else:
        duplicates = master_count - dedup_count
        print(f"WARNING: Found {duplicates} duplicate orders")
        df_master = df_deduped

    null_keys = df_master.filter(col("order_id").isNull()).count()
    if null_keys == 0:
        print("No null order_id values")
    else:
        print(f"WARNING: Found {null_keys} records with null order_id")

    # ===== STEP 7: Write merged data =====
    print("\n[STEP 7] Writing merged data to S3...")
    output_path = f"{BASE_PATH}/merged/"
    df_master.write.mode("overwrite").parquet(output_path)
    final_count = df_master.count()
    print(f"Written {final_count} merged records to {output_path}")

    # ===== STEP 8: Show final results =====
    print("\n[STEP 8] Final data snapshot:")
    df_master.orderBy("order_id").show(15, truncate=False)

    print("\n" + "=" * 70)
    print("CDC MERGE SUMMARY")
    print("=" * 70)
    print(f"Source records:        {source_count}")
    print(f"Inserted:            + {insert_count}")
    print(f"Updated:             ~ {update_count}")
    print(f"Deleted:             - {delete_count}")
    print(f"Final merged records:  {final_count}")
    print("=" * 70)
    print("JOB COMPLETED SUCCESSFULLY")

except Exception as e:
    print(f"\n ERROR: {str(e)}")
    traceback.print_exc()
    raise

finally:
    job.commit()
