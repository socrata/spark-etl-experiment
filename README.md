# Spark-ETL-Experiment

An experiment in using Spark as a backend for an interactive ETL system.

It consists of an Elm frontend for editing these "column mappings". When you update the mapping, it generates SQL that it sends back to Spark (via a `spark-jobserver` job), and displays the results. Currently it can only run queries on CSV files on your local filesystem.

## Run

### 0. `brew install sbt && npm install elm -g`

### 1. Get [`spark-jobserver/spark-jobserver`](https://github.com/spark-jobserver/spark-jobserver) up & running

1. Download it as a zip (From the [releases page](https://github.com/spark-jobserver/spark-jobserver/releases); I used 0.6.1)
2. cd into it
3. In `project/Build.scala` line 66, change `compile->compile; test->test` to `compile->compile`. I was not able to build the server without this.
4. `sbt`
5. type `job-server-extra/reStart` in the SBT prompt (can't do this from the command line apparently; your server will die instantly). If successful, it'll be on `localhost:8090` (provides a nice interface)

### 2. Build the CSV Query Application

This is a Spark application which loads a CSV into a `SQLContext` and runs it.

```
# back in this repo
cd queryApplication
sbt assembly
```

### 3. Load the Query Application into the JobServer

(while still in `queryApplication`)

```
curl --data-binary @target/scala-2.10/csv-query-assembly-1.0.jar localhost:8090/jars/csv-query     
```

The jobserver is now ready to receive queries. **NB** in production we'll use jobserver's persistent contexts to make this faster, since creating a context seems to have a few hundred ms of overhead. However, contexts are annoying for development because if you update a jar during the lifetime of a context, the context just keeps using the old version :P.

### 4. Start Elm Frontend

1. cd into `ui`
2. `elm reactor`
3. Navigate to `localhost:8000/Main.elm`

The UI should be there.
