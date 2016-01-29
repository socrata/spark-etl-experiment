import com.typesafe.config.Config
import org.apache.spark.SparkContext
import org.apache.spark.sql.SQLContext
import spark.jobserver._

object GetSchemaApplication extends SparkJob {

  override def runJob(sc: SparkContext, jobConfig: Config): Any = {
    val sqlContext = new SQLContext(sc)
    val df = sqlContext.read
      .format("com.databricks.spark.csv")
      .option("header", "true")
      .option("inferSchema", "false") // TODO set to true, map to SOQL types
      .load(jobConfig.getString("localPath"))

    df.registerTempTable(jobConfig.getString("tablename"))
    val results = sqlContext.sql(jobConfig.getString("query"))
    sqlContext.dropTempTable(jobConfig.getString("tablename"))

    Map(
      "names" -> results.columns,
      "values" -> results.map(_.toSeq).collect()
    )
  }

  override def validate(sc: SparkContext, config: Config): SparkJobValidation =
    if (config.hasPath("query") && config.hasPath("tablename"))
      SparkJobValid
    else
      SparkJobInvalid("need keys 'query', 'pathname'")

}