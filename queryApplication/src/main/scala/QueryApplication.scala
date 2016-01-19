import com.typesafe.config.Config
import org.apache.spark.sql.SQLContext
import spark.jobserver.{SparkJobInvalid, SparkJobValid, SparkJobValidation, SparkSqlJob}

object QueryApplication extends SparkSqlJob {

  def runJob(sc: SQLContext, jobConfig: Config): Any = {
    val df = sc
      .read
      .format("com.databricks.spark.csv")
      .option("header", "true")
      .option("inferSchema", "true")
      .load(jobConfig.getString("path"))
    df.registerTempTable(jobConfig.getString("tablename"))
    sc.sql(jobConfig.getString("query")).collect()
  }

  def validate(sc: SQLContext, config: Config): SparkJobValidation =
    if(config.hasPath("query") && config.hasPath("tablename") && config.hasPath("path"))
      SparkJobValid
    else
      SparkJobInvalid("needs keys query, tablename, and path")

}
