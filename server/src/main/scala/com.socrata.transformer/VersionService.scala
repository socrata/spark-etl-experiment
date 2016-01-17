package com.socrata.transformer

import com.socrata.http.server._
import org.slf4j.LoggerFactory
import org.joda.time.DateTime
import com.rojoma.json.v3.codec.JsonEncode
import buildinfo.BuildInfo

import com.socrata.http.server.implicits._
import com.socrata.http.server.responses._
import com.socrata.http.server.routing.SimpleResource

object VersionService extends SimpleResource {
  private val logger = LoggerFactory.getLogger(getClass)

  override def get: HttpRequest => HttpResponse = { req =>
    logger.info("/version")
    OK ~> Json(JsonEncode.toJValue(
                Map("version" -> BuildInfo.version,
                    "scalaVersion" -> BuildInfo.scalaVersion,
                    "buildTime" -> new DateTime(BuildInfo.buildTime).toString)))
  }
}
