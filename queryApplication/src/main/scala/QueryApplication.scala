import java.io.InputStream

import com.amazonaws.auth.ClasspathPropertiesFileCredentialsProvider
import com.amazonaws.services.s3._
import com.amazonaws.services.s3.model._
import com.typesafe.config.Config
import org.apache.spark._
import org.apache.spark.sql.types.{StringType, StructField, StructType}
import org.apache.spark.sql.{DataFrame, Row, SQLContext}
import spark.jobserver.{SparkJob, SparkJobInvalid, SparkJobValid, SparkJobValidation}

import scala.collection.JavaConversions._
import scala.collection.immutable
import scala.collection.mutable._
import scala.io.Source

object QueryApplication extends SparkJob {
  def s3 = new AmazonS3Client(new ClasspathPropertiesFileCredentialsProvider())

  def listKeysInBucket(bucket: String, prefix: String): ObjectListing = {
    val request = new ListObjectsRequest()
    request.setBucketName(bucket)
    request.setPrefix(prefix)
    request.setMaxKeys(100) // need a good way to deal with this
    s3.listObjects(request)
  }

  def runJob(sc: SparkContext, jobConfig: Config): Any = {
    if (jobConfig.hasPath("s3source"))
      s3Job(sc, jobConfig)
    else
      localJob(new SQLContext(sc), jobConfig)
  }

  def s3Job(sc: SparkContext, jobConfig: Config): Any = {
    val schemaString = jobConfig.getString("s3source.schema")
    val bucket = jobConfig.getString("s3source.bucket")
    val prefix = jobConfig.getString("s3source.prefix")
    val keys = listKeysInBucket(bucket, prefix)

    val rdd = sc.parallelize(keys.getObjectSummaries.map(_.getKey).toList)
                .flatMap { key =>
                   println(key)
                   Source.fromInputStream(s3.getObject(bucket, key).getObjectContent: InputStream).getLines
                }

    val sqc = new SQLContext(sc)

    val schemaParts = schemaString.split(",")
    val schema = StructType(
      schemaParts.map(fieldName => StructField(fieldName.trim, StringType, true))
    )
    val row = rdd.map(_.split(','))
                 // This is an attempt, albeit ugly to sidestep the array length issue described below, no joy tho
                 .map(r => {
                   val rLength = r.length
                   var rPrime = r
                   for(i <- rLength to schemaParts.length) { rPrime = rPrime :+ "" }
                   rPrime
                 })
                 .map(Row.fromSeq(_)) // --> creating the row with this method _appears_ to create rows correctly but leads to index out of bounds errors on the collect step
//                 .map(r => Row(r(0), r(1))) --> creating the row using this method leads to success but inflexible w/r to schema length
    row.foreach(r => {
      if (r.length < 22) {
        println(r)
        println(r.length)
      }
    })
    val df = sqc.createDataFrame(row, schema)
    df.registerTempTable(jobConfig.getString("tablename"))
    val result = sqc.sql(jobConfig.getString("query"))
    resultsToJson(result)
  }

  def localJob(sqlContext: SQLContext, jobConfig: Config): Any = {
    val df = sqlContext.read
      .format("com.databricks.spark.csv")
      .option("header", "true")
      .option("inferSchema", "false")
      .load(jobConfig.getString("localPath"))

    df.registerTempTable(jobConfig.getString("tablename"))
    val results = sqlContext.sql(jobConfig.getString("query"))
    sqlContext.dropTempTable(jobConfig.getString("tablename"))

    resultsToJson(results)
  }

  def resultsToJson(df: DataFrame): Any = {
    val columns = df.columns
    immutable.Map(
      "names" -> columns,
      "values" -> df.collect().map(_.toSeq.map({ thing => // this is bad
        if (thing == null) "null" else thing.toString
       }))
    )
  }

  def validate(sc: SparkContext, config: Config): SparkJobValidation = {
    val hasS3Source = config.hasPath("s3source.bucket") && config.hasPath("c3source.prefix") && config.hasPath("schema")
    val hasLocalSource = config.hasPath("localPath")
    if (config.hasPath("query") && config.hasPath("tablename")
          && (hasLocalSource || hasS3Source))
      SparkJobValid
    else
      SparkJobInvalid("needs query, tablename, and either s3source.[bucket, prefix, schema] or localPath")
  }
}
