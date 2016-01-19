module TypedTable where


import Model exposing (..)


type alias TypedTable =
  { fieldNames : List ColumnName
  , values : List (List String)
  }
