module Server where

import Http exposing (defaultSettings)
import Json.Decode as JsDec exposing (..)
import Json.Encode as JsEnc
import Task exposing (Task)

import Model exposing (TypedTable, CellResult(..))
import Config exposing (Config)
import Utils


type QueryError
  = HttpError { statusCode : Int, statusText : String, body : String }
  | JsonParseError String
  | ConnectionError Http.RawError


runQuery : Config -> String -> Decoder CellResult -> Task QueryError TypedTable
runQuery config query cellDecoder =
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
              case JsDec.decodeString (queryResult cellDecoder) str of
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
      --, url = config.jobServerUrl ++ "/jobs?appName=csv-query&sync=true&context=" ++ config.jobServerContext ++ "&classPath=QueryApplication"
      , url = config.jobServerUrl ++ "/jobs?appName=csv-query&sync=true&classPath=QueryApplication"
      , body = body
      }
    |> Task.mapError ConnectionError)
    `Task.andThen` parseResponse


queryResult : Decoder CellResult -> JsDec.Decoder TypedTable
queryResult cellDecoder =
  let
    tableItself =
      object2
        (\names values -> { fieldNames = names, values = values })
        ("names" := list string)
        ("values" := list row)

    row =
      customDecoder (list (maybe string)) joinPairs

    joinPairs : List (Maybe String) -> Result String (List CellResult)
    joinPairs maybeStrings =
      groupPairs maybeStrings
        |> Utils.getMaybe "odd row length"
        |> List.map
            (\(maybeOriginal, maybeParsed) ->
              case maybeOriginal of
                Nothing ->
                  NullInData

                Just original ->
                  case maybeParsed of
                    Just parsed ->
                      ParsedValue parsed

                    Nothing ->
                      ParseError original
            )
        |> Ok
  in
    object1 identity ("result" := tableItself)


{-| Nothing: odd list length -}
groupPairs : List a -> Maybe (List (a, a))
groupPairs list =
  let
    accum item (maybeFirst, soFar) =
      case maybeFirst of
        Just x ->
          (Nothing, (item, x) :: soFar)

        Nothing ->
          (Just item, soFar)
  in
    case List.foldr accum (Nothing, []) list of
      (Nothing, soFar) ->
        Just soFar

      _ ->
        Nothing


cellResult : JsDec.Decoder CellResult
cellResult =
  oneOf
    [ null NullInData
    , customDecoder
        (object2
          (\original parsed ->
            { original = original
            , parsed = parsed
            })
          ("originalValue" := string)
          ("parsedValue" := maybe string)
        )
        (\{original, parsed} ->
          case parsed of
            Just parsedVal ->
              Ok (ParsedValue parsedVal)

            Nothing ->
              Ok (ParseError original)
        )
    ]


initialQuery : Config -> Task QueryError TypedTable
initialQuery config =
  runQuery
    config
    ("select * from " ++ config.tableName ++ " limit 20")
    (string |> map ParsedValue)
