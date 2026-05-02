import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col, round as spark_round, to_date, current_timestamp, when

args = getResolvedOptions(sys.argv, ["JOB_NAME", "source_database", "source_table", "output_path"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Read raw sales data from Glue Data Catalog
source_df = glueContext.create_dynamic_frame.from_catalog(
    database=args["source_database"],
    table_name=args["source_table"],
    transformation_ctx="source_df",
)

df = source_df.toDF()

# Clean and enrich: parse dates, round amounts, derive revenue category
df = (
    df.withColumn("sale_date", to_date(col("sale_date"), "yyyy-MM-dd"))
    .withColumn("amount", spark_round(col("amount").cast("double"), 2))
    .withColumn("quantity", col("quantity").cast("int"))
    .withColumn(
        "revenue_category",
        when(col("amount") >= 1000, "high")
        .when(col("amount") >= 100, "medium")
        .otherwise("low"),
    )
    .withColumn("processed_at", current_timestamp())
    .dropDuplicates(["sale_id"])
    .filter(col("sale_id").isNotNull() & col("amount").isNotNull())
)

output_dyf = DynamicFrame.fromDF(df, glueContext, "output_dyf")
glueContext.write_dynamic_frame.from_options(
    frame=output_dyf,
    connection_type="s3",
    connection_options={"path": args["output_path"], "partitionKeys": ["sale_date"]},
    format="glueparquet",
    format_options={"compression": "snappy"},
    transformation_ctx="output_dyf",
)

job.commit()
