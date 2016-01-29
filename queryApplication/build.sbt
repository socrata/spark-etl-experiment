name := "csv-query"

version := "1.0"

scalaVersion := "2.10.3"

libraryDependencies ++= Seq(
  "com.databricks"   %% "spark-csv"         % "1.3.0",
  "org.apache.spark" %% "spark-sql"         % "1.6.0" % "provided",
  "org.apache.spark" %% "spark-core"        % "1.6.0" % "provided",
  "spark.jobserver"  %% "job-server-api"    % "0.6.1" % "provided",
  "spark.jobserver"  %% "job-server-extras" % "0.6.1" % "provided",
  "com.amazonaws"    %  "aws-java-sdk-core" % "1.10.49",
  "com.amazonaws"    %  "aws-java-sdk-s3"   % "1.10.49",
  "joda-time"        % "joda-time"          % "2.9.2"
)

resolvers += "Job Server Bintray" at "https://dl.bintray.com/spark-jobserver/maven"

assemblyMergeStrategy in assembly := {
  case PathList("about.html") => MergeStrategy.rename
  case x =>
    val oldStrategy = (assemblyMergeStrategy in assembly).value
    oldStrategy(x)
}
