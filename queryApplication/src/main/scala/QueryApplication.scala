import com.typesafe.config.Config
import org.apache.spark.sql.SQLContext
import spark.jobserver.{SparkJobInvalid, SparkJobValid, SparkJobValidation, SparkSqlJob}

object LoadApplication extends SparkSqlJob {
  def runJob(sc: SQLContext, jobConfig: Config): Any = {
    val df = sc
      .read
      .format("com.databricks.spark.csv")
      .option("header", "true")
      .option("inferSchema", "true")
      .load(jobConfig.getString("path"))
    df.registerTempTable(jobConfig.getString("tablename"))
  }

  def validate(sc: SQLContext, config: Config): SparkJobValidation =
    if(config.hasPath("path") && config.hasPath("tablename"))
      SparkJobValid
    else
      SparkJobInvalid("needs keys 'path' and 'tablename'")
}

object QueryApplication extends SparkSqlJob {

  def runJob(sc: SQLContext, jobConfig: Config): Any = {
    val result = sc.sql(jobConfig.getString("query"))
    val columns = result.columns
    val rows = result.collect()
    Map(
      "names" -> columns,
      "values" -> rows.map(_.toSeq.map({ thing => // this is bad
        if (thing == null) "null" else thing.toString
      }))
    )
  }

  def validate(sc: SQLContext, config: Config): SparkJobValidation =
    if(config.hasPath("query"))
      SparkJobValid
    else
      SparkJobInvalid("needs key 'query'")

}
