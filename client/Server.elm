module Server where

import Http
import Json.Decode as JsDec exposing (..)
import Json.Encode as JsEnc
import Task exposing (Task)

import TypedTable exposing (TypedTable)


runQuery : { path : String, tableName : String, query : String } -> Task Http.Error TypedTable
runQuery {path, tableName, query} =
  let
    body =
      Http.string <|
        JsEnc.encode
          0
          (JsEnc.object
            [ ("path", JsEnc.string path)
            , ("tablename", JsEnc.string tableName)
            , ("query", JsEnc.string query)
            ])
  in
    Http.post
      queryResult
      "http://localhost:8090/jobs?appName=csv-query&sync=true&context=sql-context-7&classPath=QueryApplication"
      body


queryResult : JsDec.Decoder TypedTable
queryResult =
  let
    tableItself =
      object2
        (\names values -> { fieldNames = names, values = values })
        ("names" := list string)
        ("values" := list (list string))
  in
    object1 identity ("result" := tableItself)
