module Server where

import Http exposing (defaultSettings)
import Json.Decode as JsDec exposing (..)
import Json.Encode as JsEnc
import Task exposing (Task)

import Model exposing (TypedTable)
import Config exposing (Config)


type QueryError
  = HttpError { statusCode : Int, statusText : String, body : String }
  | JsonParseError String
  | ConnectionError Http.RawError


runQuery : Config -> String -> Task QueryError TypedTable
runQuery config query =
  let
    basicFields =
      [ ("tablename", JsEnc.string config.tableName)
      , ("query", JsEnc.string query)
      ]

    sourceFields =
      case config.dataSource of
        Config.S3Source attrs ->
          [ ( "s3source"
            , JsEnc.object
                [ ("bucket", JsEnc.string attrs.bucket)
                , ("prefix", JsEnc.string attrs.chunkPrefix)
                , ("schema", JsEnc.string "foo,bar,baz")
                ]
            )
          ]

        Config.LocalSource path ->
          [("localPath", JsEnc.string path)]

    body =
      Http.string <|
        JsEnc.encode
          0
          (JsEnc.object <| basicFields ++ sourceFields)

    parseResponse response =
      case response.status of
        200 ->
          case response.value of
            Http.Text str ->
              case JsDec.decodeString queryResult str of
                Ok table ->
                  Task.succeed table

                Err err ->
                  JsonParseError err
                    |> Task.fail

            Http.Blob _ ->
              Debug.crash "wai"

        _ ->
          { statusCode = response.status
          , statusText = response.statusText
          , body =
              case response.value of
                Http.Text str ->
                  str

                Http.Blob _ ->
                  Debug.crash "wai"
          }
          |> HttpError
          |> Task.fail

  in
    (Http.send
      defaultSettings
      { verb = "POST"
      , headers = []
      , url = config.jobServerUrl ++ "/jobs?appName=csv-query&sync=true&context=" ++ config.jobServerContext ++ "&classPath=QueryApplication"
      , body = body
      }
    |> Task.mapError ConnectionError)
    `Task.andThen` parseResponse


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


initialQuery : Config -> Task QueryError TypedTable
initialQuery config =
  runQuery config ("select * from " ++ config.tableName ++ " limit 20")
