module Steps where

import Dict exposing (Dict)
import Set exposing (Set)


type alias ColumnName =
  String


type alias FuncName =
  String


type alias Schema = -- aka record
  List (ColumnName, SoqlType)


type alias SchemaMapping =
  List (ColumnName, Expr)


type Expr
  = SourceColumn ColumnName
  | FunApp FuncName (List Expr)
  | StringLit String
  | NumberLit Int
  | DoubleLit Float


type alias Function =
  { arguments : FunArgs
  , returnType : SoqlType
  }


type FunArgs
  = VarArgs SoqlType
  | NormalArgs (List (String, SoqlType))


builtinFunctions =
  [ ( "concat"
    , { arguments = VarArgs SoqlText
      , returnType = SoqlText
      }
    )
  , ( "parseInt"
    , { arguments = NormalArgs [("input", SoqlText)]
      , returnType = SoqlNumber
      }
    )
  , ( "parseFloatingTimestamp"
    , { arguments = NormalArgs [("input", SoqlText), ("format", SoqlText)]
      , returnType = SoqlFloatingTimestamp
      }
    )
  ]


type TypeError
  = WrongArgs
      { expected : FunArgs
      , given : List SoqlType
      }
  | NonexistentFunction FuncName
  | NonexistentColumn ColumnName
  | MultipleErrors (List TypeError)


type alias Env =
  { functions : Dict FuncName Function
  , columns : Set ColumnName
  }


exprType : Env -> Expr -> Result TypeError SoqlType
exprType env expr =
  case expr of
    SourceColumn colName ->
      if Set.member colName env.columns then
        Ok SoqlText
      else
        Err (NonexistentColumn colName)

    FunApp name args ->
      case Dict.get name env.functions of
        Just fun ->
          let
            argTypeResults =
              args |> List.map (exprType env)
          in
            case getOks argTypeResults of
              Ok argTypes ->
                if argsMatch fun.arguments argTypes then
                  Err (WrongArgs { given = argTypes, expected = fun.arguments })
                else
                  Ok fun.returnType

              Err errs ->
                Err (MultipleErrors errs)

        Nothing ->
          Err (NonexistentFunction name)

    StringLit _ ->
      Ok SoqlText

    DoubleLit _ ->
      Ok SoqlDouble

    NumberLit _ ->
      Ok SoqlNumber


schemaType : SchemaMapping -> Env -> Result TypeError Schema
schemaType mapping env =
  mapping
    |> List.map (snd >> exprType env)
    |> getOks
    |> Result.formatError MultipleErrors


argsMatch : FunArgs -> List SoqlType -> Bool
argsMatch expectedArgs givenArgs =
  case expectedArgs of
    VarArgs ty ->
      givenArgs |> List.all (\argTy -> argTy == ty)

    NormalArgs typeList ->
      (typeList |> List.map snd) == givenArgs


getOks : List (Result a b) -> Result (List a) (List b)
getOks results =
  let
    go soFarErr soFarOk remaining =
      case results of
        [] ->
          case (soFarErr, soFarOk) of
            ([], xs) ->
              Ok xs

            (errs, _) ->
              Err errs

        (Ok x::xs) ->
          go soFarErr (x::soFarOk) xs

        (Err x::xs) ->
          go (x::soFarErr) soFarOk xs
  in
    go [] [] results


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


type alias TableName =
  String


type Step
  = DropColumn ColumnName
  | RenameColumn ColumnName ColumnName
  | ApplyFunction FuncName ColumnName
