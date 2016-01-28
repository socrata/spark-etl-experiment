module Config where

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)

import StartApp.Simple as StartApp

import PrimitiveEditors
import S3Source exposing (S3Source)
import Tabs
import Utils

-- TODO: codegen for Elm forms from types!

type alias Config =
  { jobServerUrl : String
  , tableName : String
  , jobServerContext : String
  , dataSource : DataSource
  }


type DataSource
  = S3Source S3Source
  | LocalSource String


defaultConfig : Config
defaultConfig =
  { jobServerUrl = "http://localhost:8090"
  , tableName = "taxis"
  , jobServerContext = "basic-context"
  , dataSource =
      LocalSource "/Users/peterv/Downloads/yellow_tripdata_2012.csv"
      --S3Source
        --{ bucket = "socrata-publishing-test-files"
        --, chunkPrefix = "crimes/crimes_part"
        --}
  }


type Action
  = UpdateJobserverUrl String
  | UpdateTableName String
  | UpdateJobServerContext String
  | UpdateS3Source S3Source.Action
  | UpdateLocalSource String
  | SwitchToLocalSource
  | SwitchToS3Source


update : Action -> Config -> Config
update action model =
  let d = Debug.log "action"
  in case action of
    UpdateJobserverUrl newValue ->
      { model | jobServerUrl = newValue }

    UpdateTableName newValue ->
      { model | tableName = newValue }

    UpdateJobServerContext newValue ->
      { model | jobServerContext = newValue }

    UpdateS3Source action ->
      case model.dataSource of
        S3Source s3attrs ->
          { model | dataSource = S3Source (S3Source.update action s3attrs) }

        LocalSource _ ->
          Debug.crash "no"

    UpdateLocalSource newPath ->
      case model.dataSource of
        LocalSource _ ->
          { model | dataSource = LocalSource newPath }

        _ ->
          Debug.crash "no"

    SwitchToLocalSource ->
      { model | dataSource = LocalSource "" }

    SwitchToS3Source ->
      { model | dataSource = S3Source { bucket = "", chunkPrefix = "" } }


view : Signal.Address Action -> Config -> Html
view addr model =
  let
    configField : String -> (String -> Action) -> String -> Html
    configField name actionWrapper currentValue =
      tr
        []
        [ td [] [ text name ]
        , td
            []
            [ PrimitiveEditors.stringEditor
                (Signal.forwardTo addr actionWrapper)
                50
                currentValue
            ]
        ]
  in
    div
      []
      [ h1 [] [ text "Config" ]
      , table
          []
          [ configField "jobServerUrl" UpdateJobserverUrl model.jobServerUrl
          , configField "tableName" UpdateTableName model.tableName
          --, configField "jobServerContext" UpdateJobServerContext model.jobServerContext
          ]
      , text "Source: "
      , Tabs.tabs
          addr
          [ ("Local", SwitchToLocalSource)
          , ("S3", SwitchToS3Source)
          ]
          (case model.dataSource of
            S3Source _ -> "S3"
            LocalSource _ -> "Local"
          )
      , case model.dataSource of
          S3Source s3attrs ->
            S3Source.view (Signal.forwardTo addr UpdateS3Source) s3attrs

          LocalSource path ->
            div
              []
              [ PrimitiveEditors.stringEditor
                  (Signal.forwardTo addr UpdateLocalSource)
                  50
                  path
              ]
      ]


main =
  StartApp.start
    { model = defaultConfig
    , view = view
    , update = update
    }
