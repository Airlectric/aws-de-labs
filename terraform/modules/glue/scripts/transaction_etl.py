import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col, to_timestamp, current_timestamp, when

args = getResolvedOptions(sys.argv, ["JOB_NAME", "source_database", "source_table", "output_path"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Read raw transaction log from Glue Data Catalog
source_df = glueContext.create_dynamic_frame.from_catalog(
    database=args["source_database"],
    table_name=args["source_table"],
    transformation_ctx="source_df",
)

df = source_df.toDF()

# Normalize timestamps, cast numeric fields, label transaction status
df = (
    df.withColumn("transaction_time", to_timestamp(col("transaction_time"), "yyyy-MM-dd HH:mm:ss"))
    .withColumn("amount", col("amount").cast("double"))
    .withColumn(
        "status_label",
        when(col("status") == "S", "success")
        .when(col("status") == "F", "failed")
        .when(col("status") == "P", "pending")
        .otherwise("unknown"),
    )
    .withColumn("processed_at", current_timestamp())
    .dropDuplicates(["transaction_id"])
    .filter(col("transaction_id").isNotNull())
)

output_dyf = DynamicFrame.fromDF(df, glueContext, "output_dyf")
glueContext.write_dynamic_frame.from_options(
    frame=output_dyf,
    connection_type="s3",
    connection_options={"path": args["output_path"], "partitionKeys": []},
    format="glueparquet",
    format_options={"compression": "snappy"},
    transformation_ctx="output_dyf",
)

job.commit()
