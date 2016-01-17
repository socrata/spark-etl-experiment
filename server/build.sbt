name := "transformer"

scalaVersion := "2.11.7"

libraryDependencies ++= Seq(
  "com.socrata"               %% "socrata-http-jetty"      % "3.4.1" excludeAll(
    ExclusionRule(organization = "com.socrata", name = "socrata-http-common")),
  "com.socrata"               %% "socrata-http-client"     % "3.4.1" excludeAll(
    ExclusionRule(organization = "com.socrata", name = "socrata-http-common")),
  "com.socrata"               %% "socrata-http-common"     % "3.4.1" excludeAll(
    ExclusionRule(organization = "com.rojoma")),
  "com.socrata"               %% "socrata-curator-utils"   % "1.0.3" excludeAll(
    ExclusionRule(organization = "com.socrata", name = "socrata-http-client"),
    ExclusionRule(organization = "com.socrata", name = "socrata-http-jetty")),
  "ch.qos.logback"             % "logback-classic"         % "1.1.3",
  "org.apache.curator"         % "curator-x-discovery"     % "2.8.0"
)

// Test dependencies

libraryDependencies ++= Seq(
  "org.mockito"               % "mockito-core"             %"1.10.19" % "test"
)

val TestOptionNoTraces = "-oD"
val TestOptionShortTraces = "-oDS"
val TestOptionFullTraces = "-oDF"

testOptions in Test += Tests.Argument(TestFrameworks.ScalaTest, TestOptionNoTraces)

enablePlugins(sbtbuildinfo.BuildInfoPlugin)

// Setup revolver.
Revolver.settings
