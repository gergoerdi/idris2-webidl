module Text.WebIDL.Codegen.Rules

import Data.List
import Data.List.Elem
import Data.Validated
import Data.SortedMap
import Text.WebIDL.Types
import Text.WebIDL.Codegen.Types
import Text.WebIDL.Codegen.Util
import Text.PrettyPrint.Prettyprinter

%default total

||| An external, un-parameterized Javascript type, represented
||| by an identifier. Such a type comes with a parent
||| type (given as an `inheritance` value in the spec)
||| and a number of mixed in types.
|||
||| The actual name of the type is not included, as the set
||| of types is given in `Env` as as `SortedMap`.
public export
record JSType where
  constructor MkJSType
  parent : Maybe Identifier
  mixins : List Identifier

||| The set of external un-parameterized types from the
||| whole spec.
public export
JSTypes : Type
JSTypes = SortedMap Identifier JSType

jsTypes : List Domain -> JSTypes
jsTypes ds =
  let types =  (ds >>= map dictToType . dictionaries)
            ++ (ds >>= map interfaceToType . interfaces)

      includes = ds >>= includeStatements

      initialMap = SortedMap.fromList types

   in foldl mixin initialMap includes

  where dictToType : Dictionary -> (Identifier,JSType)
        dictToType (MkDictionary _ n i _) = (n, MkJSType i Nil)

        interfaceToType : Interface -> (Identifier,JSType)
        interfaceToType (MkInterface _ n i _) = (n, MkJSType i Nil)

        mixin : JSTypes -> Includes -> JSTypes
        mixin ts (MkIncludes _ n incl) =
          case lookup n ts of
               Nothing => ts
               Just js => let js2 = record {mixins $= (incl ::)} js
                           in insert n js2 ts


||| The parent types and mixins of a type. This is
||| used by the code generator to implement the
||| `JS.Inheritance.JSType` instances.
public export
record Supertypes where
  constructor MkSupertypes
  parents : List Identifier
  mixins  : List Identifier

objectOnly : Supertypes
objectOnly = MkSupertypes [MkIdent "Object"] []

||| Calculates the supertypes and mixins for a given
||| identifier.
|||
|||  @maxIterations : Maximal number of iterations. Without this,
|||                   the algorithm might loop forever in case of
|||                   cyclic dependencies. This value corresponds
|||                   to the maximal length of the inheritance chain.
export
supertypes : JSTypes -> (maxIterations : Nat) -> Identifier -> Supertypes
supertypes _   0    i = objectOnly
supertypes js (S k) i =
  case lookup i js of
       Nothing                              => objectOnly

       Just $ MkJSType Nothing mixins       =>
         record { mixins = mixins } objectOnly

       Just $ MkJSType (Just parent) mixins =>
         let MkSupertypes parents mixins2 = supertypes js k parent
          in MkSupertypes (parent :: parents) (mixins ++ mixins2)

--------------------------------------------------------------------------------
--          Codegen Errors
--------------------------------------------------------------------------------

public export
data CodegenErr : Type where
  CBInterfaceInvalidOps  : Domain -> Identifier -> Nat -> CodegenErr
  MandatoryAfterOptional : Domain -> Identifier -> OperationName -> CodegenErr
  RegularOpWithoutName   : Domain -> Identifier -> CodegenErr
  VarArgAndOptionalArgs  : Domain -> Identifier -> OperationName -> CodegenErr
  VarArgConstructor      : Domain -> Identifier -> CodegenErr
  VarArgNotLastArg       : Domain -> Identifier -> OperationName -> CodegenErr

public export
Codegen : Type -> Type
Codegen = Either (List CodegenErr)

public export
CodegenV : Type -> Type
CodegenV = Validated (List CodegenErr)

--------------------------------------------------------------------------------
--          Functions
--------------------------------------------------------------------------------

||| A function argument in the code generator.
public export
record Arg where
  constructor MkArg
  name : IdrisIdent
  type : CGType

public export
obj : IdrisIdent
obj = II "obj" Refl

export
arg : ArgumentName -> IdlType -> Arg
arg n = MkArg (fromString n.value) . fromIdl

public export
objArg : Identifier -> Arg
objArg = MkArg obj . Ident

public export
valArg : CGType -> Arg
valArg = MkArg (II "v" Refl)

||| A function, for which we will generate some code.
public export
data CGFunction : Type where
  ||| An attribute setter.
  AttributeSet :  (name : AttributeName)
               -> (obj  : Identifier)
               -> (tpe  : CGType)
               -> CGFunction

  ||| An attribute getter.
  AttributeGet :  (name : AttributeName)
               -> (obj  : Identifier)
               -> (tpe  : CGType)
               -> CGFunction

  ||| A setter for an optional attribute.
  OptionalAttributeSet :  (name : AttributeName)
                       -> (obj  : Identifier)
                       -> (tpe  : CGType)
                       -> CGFunction

  ||| A getter for an optional attribute.
  OptionalAttributeGet :  (name  : AttributeName)
                       -> (obj   : Identifier)
                       -> (tpe   : CGType)
                       -> (deflt : Default)
                       -> CGFunction

  ||| An interface constructor with (possibly) optional arguments.
  Constructor      :  (name         : Identifier)
                   -> (args         : List Arg)
                   -> (optionalArgs : List Arg)
                   -> CGFunction

  ||| A regular function with (possibly) optional arguments.
  Regular      :  (name         : OperationName)
               -> (args         : List Arg)
               -> (optionalArgs : List Arg)
               -> (returnType   : IdlType)
               -> CGFunction

  ||| A regular function with a terminal vararg.
  VarArg       :  (name         : OperationName)
               -> (args         : List Arg)
               -> (varArg       : Arg)
               -> (returnType   : IdlType)
               -> CGFunction

-- ||| Extract the name of a function
-- export
-- name : CGFunction -> IdrisIdent
-- name (AttributeSet n _ _)           = n
-- name (AttributeGet n _ _)           = n
-- name (OptionalAttributeSet n _ _)   = n
-- name (OptionalAttributeGet n _ _ _) = n
-- name (Constructor _ _ _)            = II "new" Refl
-- name (Regular n _ _ _)              = n
-- name (VarArg n _ _ _)               = n
-- 
-- ||| Extract the type of a function
-- export
-- type : CGFunction -> IdlType
-- type (AttributeSet _ _ t)            = t
-- type (AttributeGet _ _ t)            = t
-- type (OptionalAttributeSet _ _ t)    = t
-- type (OptionalAttributeGet _ _ t _)  = t
-- type (Constructor n _ _)             = identToType n
-- type (Regular _ _ _ t)               = t
-- type (VarArg _ _ _ t)                = t

||| This is used for sorting lists of functions to
||| the determine the order in which they appear
||| in the generated code.
|||
||| Attributes will come first, sorted by name,
||| setters, getters, and unsetter grouped together in
||| that order.
|||
||| All other functions come later and will be sorted by name.
export
priority : CGFunction -> (Nat,String,Nat)
priority (Constructor n _ _)            = (0,n.value,0)
priority (AttributeSet n _ _)           = (1,show n,1)
priority (AttributeGet n _ _)           = (1,show n,0)
priority (OptionalAttributeSet n _ _)   = (1,show n,1)
priority (OptionalAttributeGet n _ _ _) = (1,show n,0)
priority (Regular n _ _ _)              = (2,show n,0)
priority (VarArg n _ _ _)               = (2,show n,0)

-- (mandatory args, vararg or optional args)
SepArgs : Type
SepArgs = (List Arg, Either Arg (List Arg))

-- The following rules apply:
--
--  * a regular operation's name must not be `Nothing`
--  * there can only be one vararg and it must be the last
--    argument
--  * there must be no mandatory argument after an optional
--    argument
--  * optional arguments and varargs must not be mixed
fromArgList :  (domain : Domain)
            -> (definitionName : Identifier)
            -> (operationName  : OperationName)
            -> (returnType : IdlType)
            -> (arguments : ArgumentList)
            -> Codegen SepArgs
fromArgList dom ident on t args =
   case run args of
        Left x                => Left x
        Right (as,os,Nothing) => Right (as, Right os)
        Right (as,Nil,Just a) => Right (as, Left a)
        Right (as,_,Just _)   => Left [VarArgAndOptionalArgs dom ident on]

  where run :  ArgumentList -> Codegen (List Arg, List Arg, Maybe Arg)
        run []                              = Right (Nil,Nil,Nothing)
        run ((_, VarArg t n)     :: Nil)    = Right (Nil,Nil,Just $ arg n t)
        run ((_, VarArg t n)     :: _)      =
          Left [VarArgNotLastArg dom ident on]

        run ((_, Optional (_,t) n d) :: xs) =
          do (Nil,os,va) <- run xs
               | _ => Left [MandatoryAfterOptional dom ident on]
             pure (Nil, arg n t :: os, va)

        run ((_, Mandatory t n)  :: xs)     =
          map (\(as,os,m) => (arg n t :: as, os, m)) (run xs)

fromRegular :  Domain
            -> Identifier
            -> RegularOperation
            -> CodegenV (List CGFunction)
fromRegular dom ident (MkOp () t Nothing args) =
  Invalid [RegularOpWithoutName dom ident]

fromRegular dom ident (MkOp () t (Just op) args) = 
   case fromArgList dom ident op t args of
        Left x               => Invalid x
        Right (as, Left a)   => Valid [ VarArg op as a t ]
        Right (as, Right os) => Valid [ Regular op as os t ]

fromConstructor :  Domain
                -> Identifier
                -> ArgumentList
                -> CodegenV (List CGFunction)
fromConstructor dom ident args =
  let con = MkOpName "new"
   in case fromArgList dom ident con (identToType ident) args of
           Left x  => Invalid x
           Right (as, Left a)   => Invalid [VarArgConstructor dom ident]
           Right (as, Right os) => Valid [ Constructor ident as os ]

fromAttrRO : Identifier -> Readonly Attribute -> CodegenV (List CGFunction)
fromAttrRO obj (MkRO $ MkAttribute _ t n) =
  Valid [AttributeGet n obj $ fromIdl t]

fromAttr : Identifier -> Attribute -> CodegenV (List CGFunction)
fromAttr obj (MkAttribute _ t n) =
  let cgt = fromIdl t
   in Valid [AttributeGet n obj cgt, AttributeSet n obj cgt]


dictFuns : Dictionary -> List CGFunction
dictFuns d = d.members >>= fromMember . snd
  where fromMember : DictionaryMemberRest -> List CGFunction
        fromMember (Required _ t n) =
          let an = MkAttributeName n.value
              cgt = fromIdl t
           in [AttributeGet an d.name cgt, AttributeSet an d.name cgt]

        fromMember (Optional t n def) =
          let an = MkAttributeName n.value
              cgt = UndefOr t
           in [ OptionalAttributeGet an d.name cgt def
              , OptionalAttributeSet an d.name cgt
              ]

mixinFuns : Domain -> Mixin -> CodegenV (List CGFunction)
mixinFuns dom m = concat <$> traverse (fromMember . snd) m.members
  where fromMember : MixinMember -> CodegenV (List CGFunction)
        fromMember (MConst _)   = Valid Nil
        fromMember (MOp op)     = fromRegular dom m.name op
        fromMember (MStr _)     = Valid Nil
        fromMember (MAttrRO ro) = fromAttrRO m.name ro
        fromMember (MAttr at)   = fromAttr m.name at

ifaceFuns : Domain -> Interface -> CodegenV (List CGFunction)
ifaceFuns dom i = concat <$> traverse (fromMember . snd) i.members
  where fromMember : InterfaceMember -> CodegenV (List CGFunction)
        fromMember (Z $ MkConstructor args) = fromConstructor dom i.name args
        fromMember (S $ Z $ IConst x)       = Valid Nil

        fromMember (S $ Z $ IOp x)          =
          case x of
               MkOp Nothing t n args => fromRegular dom i.name
                                     $  MkOp () t n args
               MkOp (Just _) _ _ _   => Valid Nil

        fromMember (S $ Z $ IStr x)        = Valid Nil
        fromMember (S $ Z $ IStatic x)     = Valid Nil
        fromMember (S $ Z $ IAttr x)       = fromAttr i.name x
        fromMember (S $ Z $ IMap x)        = Valid Nil
        fromMember (S $ Z $ ISet x)        = Valid Nil
        fromMember (S $ Z $ IAttrRO x)     = fromAttrRO i.name x
        fromMember (S $ Z $ IMapRO x)      = Valid Nil
        fromMember (S $ Z $ ISetRO x)      = Valid Nil
        fromMember (S $ Z $ IAttrInh x)    = Valid Nil
        fromMember (S $ Z $ IIterable x y) = Valid Nil
        fromMember (S $ Z $ IAsync x y xs) = Valid Nil
        fromMember (S $ S x) impossible

ifaceConstants : Interface -> List Const
ifaceConstants (MkInterface _ _ _ ms) = mapMaybe (fromMember . snd) ms
  where fromMember : InterfaceMember -> Maybe Const
        fromMember (S $ Z $ IConst x) = Just x
        fromMember _                  = Nothing

mixinConstants : Mixin -> List Const
mixinConstants (MkMixin _ _ ms) = mapMaybe (fromMember . snd) ms
  where fromMember : MixinMember -> Maybe Const
        fromMember (MConst x) = Just x
        fromMember _          = Nothing

callbackConstants : CallbackInterface -> List Const
callbackConstants (MkCallbackInterface _ _ ms) =
  mapMaybe (\(_,v) => extract Const v) ms

--------------------------------------------------------------------------------
--          Domain
--------------------------------------------------------------------------------

public export
record CGDict where
  constructor MkDict
  name      : Identifier
  super     : Supertypes
  functions : List CGFunction

public export
record CGIface where
  constructor MkIface
  name      : Identifier
  super     : Supertypes
  constants : List Const
  functions : List CGFunction

public export
record CGMixin where
  constructor MkMixin
  name      : Identifier
  constants : List Const
  functions : List CGFunction

public export
record CGCallback where
  constructor MkCallback
  name      : Identifier
  constants : List Const
  type      : IdlType
  args      : List Arg

public export
record CGDomain where
  constructor MkDomain
  name      : String
  callbacks : List CGCallback
  dicts     : List CGDict
  enums     : List Enum
  ifaces    : List CGIface
  mixins    : List CGMixin

export
domainFunctions : CGDomain -> List CGFunction
domainFunctions d =  (d.dicts  >>= functions)
                  ++ (d.ifaces >>= functions)
                  ++ (d.mixins >>= functions)

export
domains : (maxInheritance : Nat) -> List Domain -> CodegenV (List CGDomain)
domains mi ds = let ts = jsTypes ds
                 in traverse (domain ts) ds
  where domain : JSTypes -> Domain -> CodegenV CGDomain
        domain ts d = [| MkDomain (pure d.domain)
                                  (callbacks d.callbacks d.callbackInterfaces)
                                  (traverse dict d.dictionaries)
                                  (pure d.enums)
                                  (traverse iface d.interfaces)
                                  (traverse mixin d.mixins)
                      |]

    where dict : Dictionary -> CodegenV CGDict
          dict v@(MkDictionary _ n i _) =
            Valid $ MkDict n  (supertypes ts mi n) (dictFuns v)

          iface : Interface -> CodegenV CGIface
          iface v@(MkInterface _ n i _) =
            MkIface n (supertypes ts mi n) (ifaceConstants v) <$>
              ifaceFuns d v

          mixin : Mixin -> CodegenV CGMixin
          mixin v@(MkMixin _ n _) =
            MkMixin n (mixinConstants v) <$> mixinFuns d v

          callbackArg : ArgumentRest -> Arg
          callbackArg (Mandatory t n) =
            MkArg (fromString n.value) (fromIdl t)
          callbackArg (Optional (_,t) n _) =
            MkArg (fromString n.value) (UndefOr t)
          callbackArg (VarArg t n) =
            MkArg (fromString n.value) (VarArg t)

          callback : Callback -> CodegenV CGCallback
          callback (MkCallback _ n t args) =
            Valid . MkCallback n Nil t $ map (callbackArg . snd) args

          callbackIface : CallbackInterface -> CodegenV CGCallback
          callbackIface v@(MkCallbackInterface _ n ms) =
            case mapMaybe (\(_,m)   => extract RegularOperation m) ms of
                 [MkOp () t _ args] =>
                   Valid . MkCallback n (callbackConstants v) t $
                           map (callbackArg . snd) args
                   
                 xs => Invalid [CBInterfaceInvalidOps d n (length xs)]

          callbacks :  List Callback
                    -> List CallbackInterface
                    -> CodegenV (List CGCallback)
          callbacks cs cis =
            [| traverse callback cs ++ traverse callbackIface cis |]
