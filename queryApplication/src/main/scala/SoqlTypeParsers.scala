import org.apache.spark.sql.SQLContext

// for reference: CsvTypeConverters.scala in DI2

object SoqlTypeParsers {

  case class MaybeError[A](originalValue: String, parsedValue: Option[A])

  def parseText(input: String):Option[String] =
    Some(input)

  def parseCheckbox(input: String):Option[Boolean] =
    input.toLowerCase match {
      case "0" | "f" | "false" | "n" | "no" | "off" =>
        Some(false)
      case "1" | "t" | "true" | "y" | "yes" | "on" =>
        Some(true)
      case _ =>
        None
    }

  def parseNumber(input: String):Option[String] =
    try {
      BigDecimal(input)
      Some(input)
    } catch {
      case e: NumberFormatException =>
        None
    }

  def handleDataNull[A](f: String => Option[A])(input: String): Option[MaybeError[A]] =
    if(input == null)
      None
    else {
      val r = f(input)
      Some(MaybeError(input, r))
    }

  def registerUdfs(sqlContext: SQLContext):Unit = {
    sqlContext.udf.register("parseSoqlText", handleDataNull(parseText) _)
    sqlContext.udf.register("parseSoqlCheckbox", handleDataNull(parseCheckbox) _)
    sqlContext.udf.register("parseSoqlNumber", handleDataNull(parseNumber) _)
  }

}