import com.typesafe.config.Config

import java.io.InputStream
import scala.io.Source
import org.apache.spark._
import org.apache.spark.SparkContext._
import org.apache.spark.sql.SQLContext
import spark.jobserver.{SparkJobInvalid, SparkJobValid, SparkJobValidation, SparkJob}

import org.apache.spark.sql.Row
import org.apache.spark.sql.catalyst.expressions.GenericRowWithSchema
import org.apache.spark.sql.types.{StructType,StructField,StringType}

import com.amazonaws.services.s3._
import com.amazonaws.services.s3.model._
import com.amazonaws.auth.EnvironmentVariableCredentialsProvider

import scala.collection.JavaConversions._
import scala.collection.mutable._

object QueryApplication extends SparkJob {
  def s3 = new AmazonS3Client(new EnvironmentVariableCredentialsProvider())

  def listKeysInBucket(bucket: String, prefix: String): ObjectListing = {
    val request = new ListObjectsRequest()
    request.setBucketName(bucket)
    request.setPrefix(prefix)
    request.setMaxKeys(100) // need a good way to deal with this
    s3.listObjects(request)
  }

  def runJob(sc: SparkContext, jobConfig: Config): Any = {
    val schemaString = jobConfig.getString("schema")
    val bucket = jobConfig.getString("bucket")
    val prefix = jobConfig.getString("prefix")
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
                 //.map(r => Row(r(0), r(1))) --> creating the row using this method leads to success but inflexible w/r to schema length
    row.foreach(r => {
      if (r.length < 22) {
        println(r)
        println(r.length)
      }
    })
    val df = sqc.createDataFrame(row, schema)
    df.registerTempTable(jobConfig.getString("tablename"))
    val result = sqc.sql(jobConfig.getString("query"))
    val columns = result.columns
    val rows = result.collect()
    Map(
      "names" -> columns,
      "values" -> rows.map(_.toSeq.map({ thing => // this is bad
        if (thing == null) "null" else thing.toString
       }))
    )
  }

  def validate(sc: SparkContext, config: Config): SparkJobValidation =
    if(config.hasPath("schema") && config.hasPath("query") && config.hasPath("tablename") && config.hasPath("bucket") && config.hasPath("prefix"))
      SparkJobValid
    else
      SparkJobInvalid("needs query, tablename, schema, bucket and prefix")
}
