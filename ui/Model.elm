module Model where


import String
import Set exposing (Set)


type alias TypedTable =
  { fieldNames : List ColumnName
  , values : List (List CellResult)
  }


type CellResult
  = NullInData
  | ParseError String
  | ParsedValue String


type SoqlType
  = SoqlCheckbox
  | SoqlDouble
  | SoqlFloatingTimestamp
  | SoqlMoney
  | SoqlNumber
  | SoqlText
  -- geo
  | SoqlLocation
  | SoqlPoint
  | SoqlPolygon
  | SoqlLine

-- wish I got these 2 for free! vv

soqlTypes =
  [ SoqlCheckbox
  , SoqlDouble
  , SoqlFloatingTimestamp
  , SoqlMoney
  , SoqlNumber
  , SoqlText
  , SoqlLocation
  , SoqlPoint
  , SoqlPolygon
  , SoqlLine
  ]


typeByName : String -> SoqlType
typeByName name =
  case name of
    "SoqlCheckbox" ->
      SoqlCheckbox

    "SoqlDouble" ->
      SoqlDouble

    "SoqlFloatingTimestamp" ->
      SoqlFloatingTimestamp

    "SoqlMoney" ->
      SoqlMoney

    "SoqlNumber" ->
      SoqlNumber

    "SoqlText" ->
      SoqlText

    "SoqlLocation" ->
      SoqlLocation

    "SoqlPoint" ->
      SoqlPoint

    "SoqlPolygon" ->
      SoqlPolygon

    "SoqlLine" ->
      SoqlLine

    _ ->
      Debug.crash "no type by that name"


type alias ColumnName =
  String


type alias Schema =
  List (ColumnName, SoqlType)


type alias SchemaMapping =
  List (ColumnName, ColumnSource)


type ColumnSource
  = SourceColumn ColumnName
  | ParseType SoqlType ColumnSource -- date format?
  | ExtractWithRegex String Int ColumnSource
  | Concat (List ColumnSource)
  | Constant String


type alias TableName =
  String


type alias SQL =
  String


mappingToSql : TableName -> SchemaMapping -> SQL
mappingToSql tableName mapping =
  let
    columnSources =
      mapping
        |> List.map (\(name, source) -> columnSourceToSql source ++ " as `" ++ name ++ "`")
        |> String.join ", "
  in
    "SELECT " ++ columnSources ++ " FROM " ++ tableName ++ " limit 20"


mappingToInvalidCounterSql : TableName -> SchemaMapping -> SQL
mappingToInvalidCounterSql tableName mapping =
  let
    columnSources =
      mapping
        |> List.map (\(name, source) -> "sum(if(" ++ columnSourceToSql source ++ " is null,1,0)) as `" ++ name ++ "`")
        |> String.join ", "
  in
    "SELECT count(*), " ++ columnSources ++ " FROM " ++ tableName


columnSourceToSql : ColumnSource -> String
columnSourceToSql source =
  case source of
    SourceColumn columnName ->
      "`" ++ columnName ++ "`"

    ParseType colType source ->
      case colType of
        SoqlDouble ->
          "cast(" ++ columnSourceToSql source ++ " as Double)"

        SoqlFloatingTimestamp ->
          -- TODO: more date formats somehow?
          "unix_timestamp(" ++ columnSourceToSql source ++ ", 'yyyy/MM/dd HH:mm:ss a')"

        SoqlCheckbox ->
          "parseSoqlCheckbox(" ++ columnSourceToSql source ++ ")"

        SoqlMoney ->
          "TODO_parseSoqlMoney(" ++ columnSourceToSql source ++ ")"

        SoqlNumber ->
          "parseSoqlNumber(" ++ columnSourceToSql source ++ ")"

        SoqlText ->
          "parseSoqlText(" ++ columnSourceToSql source ++ ")"

        SoqlLocation ->
          "TODO_parseSoqlLocation(" ++ columnSourceToSql source ++ ")"

        SoqlPoint ->
          "TODO_parseSoqlPoint(" ++ columnSourceToSql source ++ ")"

        SoqlPolygon ->
          "TODO_parseSoqlPolygon(" ++ columnSourceToSql source ++ ")"

        SoqlLine ->
          "TODO_parseSoqlLine(" ++ columnSourceToSql source ++ ")"

    ExtractWithRegex regex index source ->
      -- escaping is tricky...
      "regexp_extract(" ++ columnSourceToSql source ++ ", \"" ++ regex ++ "\", " ++ toString index ++ ")"

    Concat sources ->
      "concat(" ++ (sources |> List.map columnSourceToSql |> String.join ", ") ++ ")"

    Constant str ->
      toString str -- puts quotes around... need to test...



-- should be able to pass in initial guess
initialMapping : TypedTable -> SchemaMapping
initialMapping table =
  table.fieldNames
    |> List.map (\name -> (name, ParseType SoqlText (SourceColumn name)))


sqlOrErrors : TableName -> List ColumnName -> SchemaMapping -> Result (List Error) SQL
sqlOrErrors tableName sourceColumns mapping =
  case findErrors sourceColumns mapping of
    [] ->
      Ok <| mappingToSql tableName mapping

    errs ->
      Err errs


setType : ColumnName -> SoqlType -> SchemaMapping -> SchemaMapping
setType columnName newType mapping =
  mapping
    |> List.map
        (\(name, source) ->
            if name == columnName then
              case source of
                SourceColumn sourceName ->
                  (name, ParseType newType (SourceColumn sourceName))

                ParseType _ (SourceColumn sourceName) ->
                  (name, ParseType newType (SourceColumn sourceName))

                _ ->
                  Debug.crash "can't set the type on this"
            else
              (name, source)
            )

-- validation


type Error
  = NonexistentSourceColumnError ColumnName
  | TypeError TypeError


findErrors : List ColumnName -> SchemaMapping -> List Error
findErrors sourceColumns mapping =
  let
    nonexistentColumnErrors =
      findNonexistentSourceColumns sourceColumns mapping
        |> Set.toList
        |> List.map NonexistentSourceColumnError

    typeErrors =
      findTypeErrors mapping
        |> List.map TypeError

  in
    nonexistentColumnErrors ++ typeErrors


findNonexistentSourceColumns : List ColumnName -> SchemaMapping -> Set ColumnName
findNonexistentSourceColumns columns mapping =
  let
    sourceColumnsUsed =
      mapping
        |> List.map (snd >> getSourceColumns)
        |> List.foldl Set.union Set.empty

    sourceColumns =
      columns
        |> Set.fromList
  in
    sourceColumnsUsed `Set.diff` sourceColumns


type TypeError
  = ExpectedButGot { source : ColumnSource, expected : SoqlType, got : SoqlType }


findTypeErrors : SchemaMapping -> List TypeError
findTypeErrors mapping =
  mapping
    |> List.map (snd >> getType)
    |> List.filterMap
        (\result ->
          case result of
            Ok _ ->
              Nothing

            Err errors ->
              Just errors
        )
    |> List.concat


getType : ColumnSource -> Result (List TypeError) SoqlType
getType source =
  case source of
    SourceColumn _ ->
      Ok SoqlText

    ParseType ty source ->
      (getType source)
      `Result.andThen` (\sourceType ->
        case sourceType of
          SoqlText ->
            Ok ty

          otherType ->
            Err
              [ ExpectedButGot
                  { got = otherType
                  , expected = SoqlText
                  , source = source
                  }
              ]
      )

    ExtractWithRegex _ _ source ->
      (getType source)
      `Result.andThen` (\sourceType ->
        case sourceType of
          SoqlText ->
            Ok SoqlText

          otherType ->
            Err
              [ ExpectedButGot
                  { expected = SoqlText
                  , got = otherType
                  , source = source
                  }
              ]
      )

    Concat sources ->
      sources
        |> List.map (\sourceCol -> (sourceCol, getType sourceCol))
        |> List.filterMap (\(sourceCol, resultTy) ->
              case resultTy of
                Ok ty ->
                  case ty of
                    SoqlText ->
                      Nothing

                    otherType ->
                      Just <|
                        [ ExpectedButGot
                            { expected = SoqlText
                            , got = otherType
                            , source = sourceCol
                            }
                        ]

                Err errs ->
                  Just errs
            )
        |> List.concat
        |>  (\errors ->
              case errors of
                [] ->
                  Ok SoqlText

                _ ->
                  Err errors
            )

    Constant _ ->
      Ok SoqlText


getSourceColumns : ColumnSource -> Set ColumnName
getSourceColumns columnSource =
  case columnSource of
    SourceColumn name ->
      Set.singleton name

    ParseType _ source ->
      getSourceColumns source

    ExtractWithRegex _ _ source ->
      getSourceColumns source

    Concat columns ->
      columns
        |> List.map getSourceColumns
        |> List.foldl Set.union Set.empty

    Constant _ ->
      Set.empty


resultantSchema : SchemaMapping -> Schema
resultantSchema mapping =
  mapping
    |> List.map (\(name, source) -> (name, columnType source))


-- assuming source column exists and is a string
columnType : ColumnSource -> SoqlType
columnType source =
  case source of
    SourceColumn _ ->
      SoqlText

    ParseType ty _ ->
      ty

    ExtractWithRegex _ _ _ ->
      SoqlText

    Concat _ ->
      SoqlText

    Constant _ ->
      SoqlText


updateColumnName : Int -> ColumnName -> SchemaMapping -> SchemaMapping
updateColumnName idx newName mapping =
  List.indexedMap
    (\curIdx (name, source) ->
      if curIdx == idx then
        (newName, source)
      else
        (name, source)
    )
    mapping

