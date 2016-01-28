module Utils where

import Html exposing (..)
import Html.Attributes exposing (..)

import Json.Decode as JsDec
import Html.Shorthand.Event exposing (onInput, onChange)


onChangeText : Signal.Address a -> (String -> a) -> Attribute
onChangeText addr f =
  onChange
    (JsDec.at ["target", "value"] JsDec.string)
    (\str -> Signal.message addr (f str))


onInputText : Signal.Address a -> (String -> a) -> Attribute
onInputText addr f =
  onInput
    (JsDec.at ["target", "value"] JsDec.string)
    (\str -> Signal.message addr (f str))


getMaybe : String -> Maybe a -> a
getMaybe msg maybe =
  case maybe of
    Just x ->
      x

    Nothing ->
      Debug.crash msg


monospaceDiv : a -> Html
monospaceDiv value =
  div
    [ style
        [ ("font-family", "monospace")
        , ("white-space", "pre-wrap")
        ]
    ]
    [ text <| toString value ]