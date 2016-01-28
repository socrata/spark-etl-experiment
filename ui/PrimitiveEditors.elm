module PrimitiveEditors where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as JsDec


stringEditor : Signal.Address String -> Int -> String -> Html
stringEditor addr editorSize currentValue =
  input
    [ type' "text"
    , on "input" (JsDec.at ["target", "value"] JsDec.string) (Signal.message addr)
    , value currentValue
    , size editorSize
    ]
    []
