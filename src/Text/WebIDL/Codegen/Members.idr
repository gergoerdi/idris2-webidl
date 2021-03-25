module Text.WebIDL.Codegen.Members

import Data.List
import Text.WebIDL.Codegen.Types
import Text.WebIDL.Codegen.Util
import Text.WebIDL.Types
import Text.WebIDL.Encoder as E

export
Pretty FloatLit where
  pretty v = pretty $ E.floatLit v

export
Pretty IntLit where
  pretty (Hex k) = pretty $ E.toDigits "0x" 16 k
  pretty (Oct k) = pretty $ E.toDigits "0o" 8 k
  pretty (I x)   = pretty x

export
Pretty ConstValue where
  pretty (B x) = pretty x
  pretty (F x) = pretty x
  pretty (I x) = pretty x

--------------------------------------------------------------------------------
--          Constants
--------------------------------------------------------------------------------

export
constants : List Const -> List (Doc ())
constants = map const . sortBy (comparing name)
  where const : Codegen Const
        const (MkConst t n v) =
          vsep [ ""
               , "public export"
               , pretty n.value <++> ":" <++> pretty t
               , pretty n.value <++> "=" <++> pretty v
               ]

--------------------------------------------------------------------------------
--          Attributes
--------------------------------------------------------------------------------

primType : (name : IdrisIdent) -> Nat -> IdlType -> Doc ()
primType name n x = typeDecl (Prim $ show name) (primReturnType x) $
                      replicate n "AnyPtr"

-- Types coming as identifiers are treated as external JS types
-- In order to support suptyping, these are converted to lowercase
-- names and the necessary implicits are added as prerequisids.
--
-- We need to make sure that implicits are added only once, though.
funType : (name : IdrisIdent) -> ArgumentList -> IdlType -> Doc ()
funType n args t =
  let implArgNames = sortedNubOn id $ mapMaybe (ident . argType . snd) args

      implicits    = implArgNames >>= toImplicit

      args2        = map (renameParams . snd) args

   in typeDeclWithImplicits n (returnType t) implicits args2

  where 

        identAndType : IdlType -> Maybe (IdlType,String,String)
        identAndType (D $ MaybeNull $ I $ MkIdent x) =
          let x2 = mapFirstChar toLower x
           in Just (D $ MaybeNull $ I $ MkIdent x2,x,x2)

        identAndType (D $ NotNull   $ I $ MkIdent x) =
          let x2 = mapFirstChar toLower x
           in Just (D $ NotNull $ I $ MkIdent x2,x,x2)

        identAndType _                               = Nothing

        ident : IdlType -> Maybe (String,String)
        ident = map (\(_,x,y) => (x,y)) . identAndType

        toImplicit : (String,String) -> List (Doc ())
        toImplicit (s,slower) = [ "Cast" <++> pretty slower <++> pretty s
                                , "ToJS" <++> pretty s
                                ]

        renameParams : ArgumentRest -> Doc ()
        renameParams (Optional (e,tpe) (MkArgName n) def) =
          case identAndType tpe of
               Just (t,_,l) => if l == n
                                  then prettyArg (Underscore n) (pretty t)
                                  else prettyArg (fromString n) (pretty t)
               Nothing => prettyArg (fromString n) (pretty tpe)

        renameParams (Mandatory tpe (MkArgName n)) =
          case identAndType tpe of
               Just (t,_,l) => if l == n
                                  then prettyArg (Underscore n) (pretty t)
                                  else prettyArg (fromString n) (pretty t)
               Nothing => prettyArg (fromString n) (pretty tpe)

        -- TODO: Properly support varargs
        renameParams (VarArg tpe (MkArgName n)) =
          case identAndType tpe of
               Just (t,_,l) => if l == n
                                  then prettyArg (Underscore n) (pretty t)
                                  else prettyArg (fromString n) (pretty t)
               Nothing => prettyArg (fromString n) (pretty tpe)


readonly : Identifier -> Attribute -> List $ Doc ()
readonly i (MkAttribute _ t (MkAttributeName n)) =
  let ii = fromString n
   in [ "" 
      , attrGet n
      , primType ii 1 t
      , ""
      , "export"
      , funType ii [objArg i] t
      ]

readwrite : Identifier -> Attribute -> List $ Doc ()
readwrite i a@(MkAttribute _ t (MkAttributeName n)) =
  readonly i a ++ [ ""
                  , attrSet n
                  , primType (setter n) 2 t
                  , ""
                  , "export"
                  , funType (setter n) [objArg i, valArg t] undefined
                  ]

export
readOnlyAttributes :  Identifier
                   -> List (Readonly Attribute)
                   -> List (Doc ())
readOnlyAttributes i = (>>= readonly i) . sortBy (comparing name) . map value

export
attributes : Identifier -> List Attribute -> List (Doc ())
attributes i = (>>= readwrite i) . sortBy (comparing name)