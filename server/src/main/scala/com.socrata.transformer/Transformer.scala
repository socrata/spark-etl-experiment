package com.socrata.transformer

import com.socrata.http.server.SocrataServerJetty

object Transformer extends App {

    val router = Router(VersionService)
    val handler = router.route _

    val server = new SocrataServerJetty(
      handler = handler,
      options = SocrataServerJetty.defaultOptions.
        withPort(TransformerConfig.port)
    )

    server.run()

}
