import org.apache.spark.sql.SQLContext
import org.joda.time.format.{DateTimeFormat, ISODateTimeFormat}

// for reference: CsvTypeConverters.scala in DI2

object SoqlTypeParsers {

  case class MaybeError(originalValue: String, parsedValue: Option[String])

  def parseText(input: String):Option[String] =
    Some(input)

  def parseCheckbox(input: String):Option[String] =
    input.toLowerCase match {
      case "0" | "f" | "false" | "n" | "no" | "off" =>
        Some("false")
      case "1" | "t" | "true" | "y" | "yes" | "on" =>
        Some("true")
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

  // TODO format as arg
  def parseDateTime(input: String):Option[String] =
    try {
      val dt = DateTimeFormat.forPattern("yyyy-MM-dd HH:mm:ss").parseDateTime(input)
      Some(ISODateTimeFormat.dateTime().print(dt))
    } catch {
      case ex: IllegalArgumentException =>
        None
    }

  def handleDataNull1(f: String => Option[String])(input: String): Option[MaybeError] =
    if(input == null)
      None
    else {
      val r = f(input)
      Some(MaybeError(input, r))
    }

  // ...?
  def handleDataNull2(f: (String, String) => Option[String])(input1: String, input2: String): Option[MaybeError] =
    if(input1 == null || input2 == null)
      None
    else {
      val r = f(input1, input2)
      Some(MaybeError(input1, r))
    }

  def registerUdfs(sqlContext: SQLContext):Unit = {
    sqlContext.udf.register("parseSoqlText", handleDataNull1(parseText) _)
    sqlContext.udf.register("parseSoqlCheckbox", handleDataNull1(parseCheckbox) _)
    sqlContext.udf.register("parseSoqlNumber", handleDataNull1(parseNumber) _)
    // v^ not really sure what the difference is between these
    sqlContext.udf.register("parseSoqlDouble", handleDataNull1(parseNumber) _)
    val twoFun = handleDataNull1(parseDateTime) _
    sqlContext.udf.register("parseSoqlTimestamp", twoFun)
  }

}