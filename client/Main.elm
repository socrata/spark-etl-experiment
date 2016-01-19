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
import TypedTable exposing (TypedTable)

type Action
  = UpdateType ColumnName SoqlType
  | UpdatePath String
  | UpdateTableName String
  | GotTable TypedTable


type alias Model =
  { sourceColumns : List ColumnName -- names assumed unique
  , mapping : SchemaMapping
  , path : String
  , tableName : String
  , tableResult : Maybe TypedTable
  }


view : Signal.Address Action -> Model -> Html
view addr model =
  div
    []
    [ text "Path:"
    , input
        [ onText addr UpdatePath
        , value model.path
        ]
        []
    , br [] []
    , text "Tablename:"
    , input
        [ onText addr UpdateTableName
        , value model.tableName
        ]
        []
    , table
        []
        [ tr
            []
            (model.mapping
              |> List.map (\(name, _) ->
                    th [] [ text name ]
                  )
            )
        , tr
            []
            (model.mapping
              |> List.map (\(name, colSource) ->
                    td []
                      [ typeSelector
                          (Signal.forwardTo addr (UpdateType name))
                          (columnType colSource)
                      ]
                  )
            )
        , tbody
            []
            (model.tableResult
              |> Maybe.map dataRows
              |> Maybe.withDefault [])
        ]
    , case model.tableResult of
        Just _ ->
          span [] []

        Nothing ->
          p
            [ style
                [ ("text-align", "center")
                , ("font-style", "italic")
                ]
            ]
            [ text "Loading..." ]
    , div
        [ style
            [ ("font-family", "monospace")
            , ("white-space", "pre-wrap")
            ]
        ]
        [ sqlOrErrors
            "crimes"
            model.sourceColumns
            model.mapping
          |> toString
          |> text
        ]
    ]


dataRows : TypedTable -> List Html
dataRows table =
  table.values
    |> List.map (\row ->
      tr
        []
        (row |> List.map (\cell -> td [] [text cell]))
    )


typeSelector : Signal.Address SoqlType -> SoqlType -> Html
typeSelector addr selectedType =
  select
    [ onText addr typeByName ]
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
  case action of
    UpdateType name newType ->
      let
        newModel =
          { model
              | mapping = setType name newType model.mapping
              , tableResult = Nothing
          }
      in
        ( newModel
        , Effects.task (getTable newModel)
        )

    UpdatePath path ->
      ( { model | path = path }
      , Effects.none
      )

    UpdateTableName name ->
      ( { model | tableName = name }
      , Effects.none
      )

    GotTable table ->
      ( { model | tableResult = Just table }
      , Effects.none
      )


getTable : Model -> Task Effects.Never Action
getTable model =
  Server.runQuery
    { path = model.path
    , tableName = model.tableName
    , query = mappingToSql model.tableName model.mapping
    }
  |> Task.toMaybe
  |> Task.map (getMaybe "query error")
  |> Task.map GotTable


app =
  let
    initModel =
      { sourceColumns = Examples.sourceColumns
      , mapping = allStringMapping Examples.sourceColumns
      , path = "/crimes.csv"
      , tableName = "crimes"
      , tableResult = Nothing
      }
  in
    StartApp.start
      { view = view
      , update = update
      , init =
          ( initModel
          , Effects.task (getTable initModel)
          )
      , inputs = []
      }


main =
  app.html


port tasks : Signal (Task Effects.Never ())
port tasks =
  app.tasks


onText : Signal.Address a -> (String -> a) -> Attribute
onText addr f =
  onChange
    (JsDec.at ["target", "value"] JsDec.string)
    (\str -> Signal.message addr (f str))


getMaybe : String -> Maybe a -> a
getMaybe msg maybe =
  case maybe of
    Just x ->
      x

    Nothing ->
      Debug.crash "msg"
