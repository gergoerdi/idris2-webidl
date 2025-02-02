module Text.WebIDL.Types.Attribute

import Data.List1
import Data.SOP
import Text.WebIDL.Types.Numbers
import Text.WebIDL.Types.StringLit
import Text.WebIDL.Types.Identifier
import Text.WebIDL.Types.Symbol

import Generics.Derive

%language ElabReflection

public export
isParenOrQuote : Char -> Bool
isParenOrQuote '(' = True
isParenOrQuote ')' = True
isParenOrQuote '[' = True
isParenOrQuote ']' = True
isParenOrQuote '{' = True
isParenOrQuote '}' = True
isParenOrQuote '"' = True
isParenOrQuote _   = False

public export
isCommaOrParenOrQuote : Char -> Bool
isCommaOrParenOrQuote ',' = True
isCommaOrParenOrQuote c   = isParenOrQuote c

public export
0 Other : Type
Other = NS I [IntLit,FloatLit,StringLit,Identifier,Keyword,Symbol]

||| ExtendedAttributeInner ::
public export
data EAInner : Type where
  |||   ( ExtendedAttributeInner ) ExtendedAttributeInner
  |||   [ ExtendedAttributeInner ] ExtendedAttributeInner
  |||   { ExtendedAttributeInner } ExtendedAttributeInner
  EAIParens : (inParens : EAInner) -> (eai : EAInner) -> EAInner

  |||   OtherOrComma ExtendedAttributeInner
  EAIOther  : (otherOrComma : Other) -> (eai : EAInner) -> EAInner

  |||   ε
  EAIEmpty  : EAInner

%runElab derive "EAInner" [Generic,Meta,Eq,Show]

namespace EAInner

  ||| Number of `Other`s.
  public export
  size : EAInner -> Nat
  size (EAIParens inParens eai)    = size inParens + size eai
  size (EAIOther otherOrComma eai) = 1 + size eai
  size EAIEmpty                    = 0

  ||| Number of `Other`s.
  public export
  leaves : EAInner -> Nat
  leaves (EAIParens inParens eai)    = leaves inParens + leaves eai
  leaves (EAIOther otherOrComma eai) = 1 + leaves eai
  leaves EAIEmpty                    = 1

  ||| Number of `Other`s.
  public export
  depth : EAInner -> Nat
  depth (EAIParens inParens eai)    = 1 + (depth inParens `max` depth eai)
  depth (EAIOther otherOrComma eai) = 1 + depth eai
  depth EAIEmpty                    = 0

||| ExtendedAttributeRest ::
|||   ExtendedAttribute
|||   ε
|||
||| ExtendedAttribute ::
public export
data ExtAttribute : Type where
  ||| ( ExtendedAttributeInner ) ExtendedAttributeRest
  ||| [ ExtendedAttributeInner ] ExtendedAttributeRest
  ||| { ExtendedAttributeInner } ExtendedAttributeRest
  EAParens : (inner : EAInner) -> (rest : Maybe ExtAttribute) -> ExtAttribute

  ||| Other ExtendedAttributeRest
  EAOther : (other : Other) -> (rest : Maybe ExtAttribute) -> ExtAttribute

%runElab derive "ExtAttribute" [Generic,Meta,Eq,Show]

namespace ExtAttribute

  ||| Number of `Other`s.
  public export
  size : ExtAttribute -> Nat
  size (EAParens inner rest) = size inner + maybe 0 size rest
  size (EAOther other rest)  = 1 + maybe 0 size rest

  ||| Number of leaves (unlike `size`, this includes empty leaves)
  public export
  leaves : ExtAttribute -> Nat
  leaves (EAParens inner rest) = leaves inner + maybe 1 leaves rest
  leaves (EAOther other rest)  = 1 + maybe 1 leaves rest

  ||| Number of `Other`s.
  public export
  depth : ExtAttribute -> Nat
  depth (EAParens inner rest) = 1 + (depth inner `max` maybe 0 depth rest)
  depth (EAOther other rest)  = 1 + maybe 0 depth rest


||| ExtendedAttributeList ::
|||   [ ExtendedAttribute ExtendedAttributes ]
|||   ε
|||
||| ExtendedAttributes ::
|||   , ExtendedAttribute ExtendedAttributes
|||   ε
public export
ExtAttributeList : Type
ExtAttributeList = List ExtAttribute

||| TypeWithExtendedAttributes ::
|||     ExtendedAttributeList Type
public export
Attributed : Type -> Type
Attributed a = (ExtAttributeList, a)

public export
interface HasAttributes a where
  attributes : a -> ExtAttributeList

public export
HasAttributes () where
  attributes = const Nil

public export
HasAttributes String where
  attributes = const Nil

public export
HasAttributes Identifier where
  attributes = const Nil

public export
HasAttributes Bool where
  attributes = const Nil

public export
HasAttributes FloatLit where
  attributes = const Nil

public export
HasAttributes IntLit where
  attributes = const Nil

public export
HasAttributes StringLit where
  attributes = const Nil

public export
(HasAttributes a, HasAttributes b) => HasAttributes (a,b) where
  attributes (x,y) = attributes x ++ attributes y

public export
HasAttributes ExtAttribute where
  attributes = pure

public export
HasAttributes a => HasAttributes (Maybe a) where
  attributes = maybe Nil attributes

public export
HasAttributes a => HasAttributes (List a) where
  attributes = concatMap attributes

public export
HasAttributes a => HasAttributes (List1 a) where
  attributes = attributes . forget

--------------------------------------------------------------------------------
--          Deriving HasAttributes
--------------------------------------------------------------------------------

public export
(all : NP HasAttributes ts) => HasAttributes (NP I ts) where
  attributes = hcconcatMap HasAttributes attributes

public export
(all : NP HasAttributes ts) => HasAttributes (NS I ts) where
  attributes = hcconcatMap HasAttributes attributes

public export
(all : POP HasAttributes ts) => HasAttributes (SOP I ts) where
  attributes = hcconcatMap HasAttributes attributes

public export
genAttributes :  Generic a code
              => POP HasAttributes code
              => a
              -> ExtAttributeList
genAttributes = attributes . from

namespace Derive

  public export %inline
  mkHasAttributes : (attrs : a -> ExtAttributeList) -> HasAttributes a
  mkHasAttributes = %runElab check (var $ singleCon "HasAttributes")

  ||| Derives an `Eq` implementation for the given data type
  ||| and visibility.
  export
  HasAttributesVis : Visibility -> DeriveUtil -> InterfaceImpl
  HasAttributesVis vis g = MkInterfaceImpl "HasAttributes" vis []
                             `(mkHasAttributes genAttributes)
                             (implementationType `(HasAttributes) g)

  ||| Alias for `EqVis Public`.
  export
  HasAttributes : DeriveUtil -> InterfaceImpl
  HasAttributes = HasAttributesVis Public

--------------------------------------------------------------------------------
--          Tests and Proofs
--------------------------------------------------------------------------------

isParenTrue : all Attribute.isParenOrQuote (unpack "(){}[]\"") = True
isParenTrue = Refl

isParenFalse : any Attribute.isParenOrQuote (unpack "=!?><:;,.-_") = False
isParenFalse = Refl

isCommaOrParenTrue : all Attribute.isCommaOrParenOrQuote (unpack ",(){}[]\"") = True
isCommaOrParenTrue = Refl

isCommaOrParenFalse : any Attribute.isCommaOrParenOrQuote (unpack "=!?><:;.-_") = False
isCommaOrParenFalse = Refl
