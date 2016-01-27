module Tabs where

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)


tabs : Signal.Address a -> List (String, a) -> String -> Html
tabs addr tabs selected =
  let
    renderTab (name, action) =
      if name == selected then
        span
          [ style
              [ ("font-weight", "bold") ]
          ]
          [ text name ]
      else
        span
          [ onClick addr action
          , style
              [ ("cursor", "pointer") ]
          ]
          [ text name ]
  in
    span
      []
      (tabs |> List.map renderTab |> List.intersperse (text " | "))
