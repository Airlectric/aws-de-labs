import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col, upper, trim, to_date, current_timestamp

args = getResolvedOptions(sys.argv, ["JOB_NAME", "source_database", "source_table", "output_path"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Read raw customer data from Glue Data Catalog
source_df = glueContext.create_dynamic_frame.from_catalog(
    database=args["source_database"],
    table_name=args["source_table"],
    transformation_ctx="source_df",
)

# Convert to Spark DataFrame for transformations
df = source_df.toDF()

# Normalize: trim whitespace, uppercase name fields, parse date columns
df = (
    df.withColumn("first_name", trim(upper(col("first_name"))))
    .withColumn("last_name", trim(upper(col("last_name"))))
    .withColumn("email", trim(col("email")))
    .withColumn("signup_date", to_date(col("signup_date"), "yyyy-MM-dd"))
    .withColumn("processed_at", current_timestamp())
    .dropDuplicates(["customer_id"])
    .filter(col("customer_id").isNotNull())
)

# Write to processed/ zone as Parquet (columnar, compressed, query-efficient)
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
