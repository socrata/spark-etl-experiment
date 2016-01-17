package com.socrata.transformer

import com.socrata.curator.{CuratedClientConfig, DiscoveryBrokerConfig}
import com.typesafe.config.ConfigFactory

object TransformerConfig {
  lazy val config = ConfigFactory.load().getConfig("com.socrata")

  lazy val port = config.getInt("transformer.port")
}
