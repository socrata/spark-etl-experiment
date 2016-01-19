package com.socrata.transformer

import com.socrata.http.server.SocrataServerJetty

import org.apache.spark._
import org.apache.spark.sql.SQLContext
import org.slf4j.LoggerFactory

object Transformer extends App {

  val logger = LoggerFactory.getLogger(getClass)

  // start up the spark application

  logger.info("BLA-4")

  val conf = new SparkConf()
    .setMaster("spark://petes-mbp-reincarnated.local:7077")
    .setAppName("transformer")
    .setJars(Seq("/Users/pete/code/transformer-ui/server/" +
      "target/scala-2.10/transformer-assembly-0.0.1-SNAPSHOT.jar"))

  logger.info("BLA-3")

  val sc = new SparkContext(conf)

  logger.info("BLA-2")

  val sqlContext = new SQLContext(sc)

  logger.info("BLA-1")

//  val df = sqlContext.read
//    .format("com.databricks.spark.csv")
//    .option("header", "true")
//    .option("inferSchema", "true")
//    .load("/Users/pete/Downloads/Crimes_-_One_year_prior_to_present.csv")

  logger.info("BLA0")

//  df.registerTempTable("crimes")

  val rdd = sc.textFile("/Users/pete/Downloads/Crimes_-_One_year_prior_to_present.csv")

  logger.info("BLA1")

  val router = Router(VersionService, QueryService(sqlContext), RDDService(rdd))
  val handler = router.route _

  logger.info("BLA2")

  val server = new SocrataServerJetty(
    handler = handler,
    options = SocrataServerJetty.defaultOptions.
      withPort(TransformerConfig.port)
  )

  logger.info("BLA3")

  server.run()

  logger.info("BLA4")

}
