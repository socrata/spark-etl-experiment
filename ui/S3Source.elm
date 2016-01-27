module S3Source where

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Json.Decode as JsDec

import PrimitiveEditors


type alias S3Source =
  { bucket : String
  , chunkPrefix : String
  }


type Action
  = UpdateBucket String
  | UpdateChunkPrefix String


view : Signal.Address Action -> S3Source -> Html
view addr model =
  table
    []
    [ tr
        []
        [ td [] [text "bucket"]
        , PrimitiveEditors.stringEditor
            (Signal.forwardTo addr UpdateBucket)
            model.bucket
        ]
    , tr
        []
        [ td [] [text "chunkPrefix"]
        , PrimitiveEditors.stringEditor
            (Signal.forwardTo addr UpdateChunkPrefix)
            model.chunkPrefix
        ]
    ]


update : Action -> S3Source -> S3Source
update action model =
  case action of
    UpdateBucket b ->
      { model | bucket = b }

    UpdateChunkPrefix cp ->
      { model | chunkPrefix = cp }
