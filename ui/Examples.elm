module Examples where

import Model exposing (..)

sourceColumns =
  [ "ID", "Case Number", "Date", "Block", "IUCR", "Primary Type", "Description"
  , "Location Description", "Arrest", "Domestic", "Beat", "District", "Ward"
  , "Community Area", "FBI Code", "X Coordinate", "Y Coordinate", "Year"
  , "Updated On", "Latitude", "Longitude", "Location"
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
