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


type Application
  = QueryApplication
  | GetSchemaApplication


runQuery : Config -> String -> Application -> Decoder TypedTable -> Task QueryError TypedTable
runQuery config query application tableDecoder =
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
              case JsDec.decodeString (apiResult tableDecoder) str of
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
      , url = config.jobServerUrl ++ "/jobs?appName=csv-query&sync=true&classPath=" ++ (toString application)
      , body = body
      }
    |> Task.mapError ConnectionError)
    `Task.andThen` parseResponse


-- TODO: account for job errors (which are 200s)
apiResult : JsDec.Decoder TypedTable -> JsDec.Decoder TypedTable
apiResult tableItselfDecoder =
  object1 identity ("result" := tableItselfDecoder)


-- TODO: schema guesses will come through here...
initialQueryDecoder : JsDec.Decoder TypedTable
initialQueryDecoder =
  let
    cell =
      oneOf
        [ null NullInData
        , string |> JsDec.map ParsedValue
        ]
  in
    object2
      (\names values ->
        { fieldNames = names
        , values = values
        }
      )
      ("names" := list string)
      ("values" := list (list cell))


withErrorsDecoder : JsDec.Decoder TypedTable
withErrorsDecoder =
  let
    row =
      list (maybe string)
        `customDecoder` joinPairs
  in
    object2
      (\names values ->
        { fieldNames = names
        , values = values
        }
      )
      ("names" := list string)
      ("values" := list row)


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


initialQuery : Config -> Task QueryError TypedTable
initialQuery config =
  runQuery
    config
    ("select * from " ++ config.tableName ++ " limit 20")
    GetSchemaApplication
    initialQueryDecoder
