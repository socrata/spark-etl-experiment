module Main where

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Html.Shorthand.Event exposing (onChange)
import Json.Decode as JsDec
import Task exposing (Task)
import Http

import StartApp
import Effects exposing (Effects)

import Model exposing (..)
import Examples
import Server
import Config exposing (Config)
import Utils
import PrimitiveEditors


type Action
  = UpdateType ColumnName SoqlType
  | QueryResult (Result Server.QueryError TypedTable)
  | ConfigAction Config.Action
  | ManualRun
  | UpdateColumnName Int ColumnName


type Model
  = MainState HasResultModel
  | InitialState Config


type alias HasResultModel =
  { config : Config
  , sourceColumns : List ColumnName -- names assumed unique
  , mapping : SchemaMapping
  , tableResult : Result Server.QueryError TypedTable
  , loading : Bool
  }


view : Signal.Address Action -> Model -> Html
view addr model =
  case model of
    InitialState config ->
      div
        []
        [ Config.view (Signal.forwardTo addr ConfigAction) config
        , button [ onClick addr ManualRun ] [ text "Go" ]
        ]

    MainState attrs ->
      div
        []
        [ Config.view (Signal.forwardTo addr ConfigAction) attrs.config
        , button [ onClick addr ManualRun ] [ text "Go" ]
        , h1 [] [text "Table"]
        , table
            []
            ([ tr
                []
                (attrs.mapping
                  |> List.indexedMap (\idx (name, _) ->
                        th
                          []
                          [ PrimitiveEditors.stringEditor
                              (Signal.forwardTo addr (UpdateColumnName idx))
                              23
                              name
                          ]
                      )
                )
            , tr
                []
                (attrs.mapping
                  |> List.map (\(name, colSource) ->
                        td []
                          [ typeSelector
                              (Signal.forwardTo addr (UpdateType name))
                              (columnType colSource)
                          ]
                      )
                )
            ] ++ (
              if attrs.loading then
                []
              else case attrs.tableResult of
                Ok table ->
                  [ tbody [] (dataRows table) ]

                Err _ ->
                  []
            ))
        , if attrs.loading then
            p [] [text "Loading..."]
          else case attrs.tableResult of
            Ok _ ->
              span [] []

            Err error ->
              Utils.monospaceDiv error
        , h1
            []
            [ text "SQL" ]
        , Utils.monospaceDiv <|
            sqlOrErrors
              "crimes"
              attrs.sourceColumns
              attrs.mapping
        ]


dataRows : TypedTable -> List Html
dataRows table =
  table.values
    |> List.map (\row ->
      tr
        []
        (row |> List.map (\cellResult -> td [] [viewCellResult cellResult]))
    )


viewCellResult : CellResult -> Html
viewCellResult result =
  case result of
    NullInData ->
      span
        [ style [("font-style", "italic")] ]
        [ text "null" ]

    ParseError original ->
      span
        [ style [("background-color", "pink")] ]
        [ text original ]

    ParsedValue parsed ->
      text parsed


typeSelector : Signal.Address SoqlType -> SoqlType -> Html
typeSelector addr selectedType =
  select
    [ Utils.onChangeText addr typeByName ]
    (soqlTypes
      |> List.map
          (\ty ->
            option
              [ selected (ty == selectedType) ]
              [ text (toString ty) ]
          )
    )


update : Action -> Model -> (Model, Effects Action)
update action model =
  case model of
    InitialState config ->
      case action of
        ConfigAction action ->
          ( InitialState (Config.update action config)
          , Effects.none
          )

        ManualRun ->
          let
            doQuery =
              Server.initialQuery config
                |> Task.toResult
                |> Task.map QueryResult
          in
            ( InitialState config
            , Effects.task doQuery
            )

        QueryResult result ->
          ( MainState
              { config = config
              , sourceColumns =
                  result
                    |> Result.map (\table -> table.fieldNames)
                    |> Result.withDefault []
              , mapping =
                  result
                    |> Result.map (\table -> initialMapping table)
                    |> Result.withDefault []
              , tableResult = result
              , loading = False
              }
          , Effects.none
          )

        _ ->
          Debug.crash "unexpected action"

    MainState attrs ->
      case action of
        UpdateType name newType ->
          let
            newAttrs =
              { attrs
                  | mapping = setType name newType attrs.mapping
                  , loading = True
              }
          in
            ( MainState newAttrs
            , Effects.task (getTable newAttrs.config newAttrs.mapping)
            )

        QueryResult result ->
          ( MainState { attrs | tableResult = result, loading = False }
          , Effects.none
          )

        ConfigAction action ->
          ( MainState { attrs | config = Config.update action attrs.config }
          , Effects.none
          )

        ManualRun ->
          ( MainState { attrs | loading = True }
          , Effects.task (getTable attrs.config attrs.mapping)
          )

        UpdateColumnName mappingIdx name ->
          let
            newMapping =
              attrs.mapping |> updateColumnName mappingIdx name
          in
            ( MainState { attrs | mapping = newMapping }
            , Effects.none
            )


getTable : Config -> SchemaMapping -> Task Effects.Never Action
getTable config mapping =
  Server.runQuery config (mappingToSql config.tableName mapping) Server.cellResult
  |> Task.toResult
  |> Task.map QueryResult


app =
  StartApp.start
    { view = view
    , update = update
    , init =
        ( InitialState Config.defaultConfig
        , Effects.none
        )
    , inputs = []
    }


main =
  app.html


port tasks : Signal (Task Effects.Never ())
port tasks =
  app.tasks
