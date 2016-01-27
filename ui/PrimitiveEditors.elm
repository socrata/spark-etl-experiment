module PrimitiveEditors where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as JsDec


stringEditor : Signal.Address String -> String -> Html
stringEditor addr currentValue =
  input
    [ type' "text"
    , on "input" (JsDec.at ["target", "value"] JsDec.string) (Signal.message addr)
    , value currentValue
    , size 50
    ]
    []
