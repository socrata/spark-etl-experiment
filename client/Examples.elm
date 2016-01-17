module Examples where

import Model exposing (..)

sourceColumns =
  [ "CASE#", "DATE  OF OCCURRENCE", "BLOCK", " IUCR", " PRIMARY DESCRIPTION"
  , " SECONDARY DESCRIPTION", " LOCATION DESCRIPTION", "ARREST", "DOMESTIC"
  , "BEAT", "WARD", "FBI CD", "X COORDINATE", "Y COORDINATE"
  , "LATITUDE", "LONGITUDE", "LOCATION"
  ]

ex1 =
  let
    mapping =
      [ ("date", ParseType SoqlFloatingTimestamp (SourceColumn "DATE  OF OCCURRENCE"))
      , ("block", SourceColumn "block")
      , ("coords", Concat [SourceColumn "X COORDINATE", Constant ", ", SourceColumn "Y COORDINATE"] )
      , ("location", Concat [ParseType SoqlDouble (SourceColumn "LOCATION")])
      ]
  in
    ( mappingToSql "crimes" mapping
    , resultantSchema mapping
    , findErrors sourceColumns mapping
    )
