module Main where

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Html.Shorthand.Event exposing (..)
import Json.Decode as JsDec

import StartApp.Simple as StartApp
import Model exposing (..)
import Examples

type Action
  = NoOp
  | UpdateType ColumnName SoqlType


type alias Model =
  { sourceColumns : List ColumnName -- names assumed unique
  , mapping : SchemaMapping
  }


view : Signal.Address Action -> Model -> Html
view addr model =
  div
    []
    [ table
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
        ]
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


typeSelector : Signal.Address SoqlType -> SoqlType -> Html
typeSelector addr selectedType =
  select
    [ onChange
        (JsDec.at ["target", "value"] JsDec.string)
        (typeByName >> Signal.message addr)
    ]
    (soqlTypes
      |> List.map
          (\ty ->
            option
              [ selected (ty == selectedType) ]
              [ text (toString ty) ]
          )
    )


update : Action -> Model -> Model
update action model =
  case action of
    NoOp ->
      model

    UpdateType name newType ->
      { model | mapping = setType name newType model.mapping }


main =
  StartApp.start
    { view = view
    , update = update
    , model =
        { sourceColumns = Debug.log "sc" Examples.sourceColumns
        , mapping = allStringMapping Examples.sourceColumns
        }
    }


getMaybe : String -> Maybe a -> a
getMaybe msg maybe =
  case maybe of
    Just x ->
      x

    Nothing ->
      Debug.crash "msg"
