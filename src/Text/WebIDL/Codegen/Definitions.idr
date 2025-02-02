module Text.WebIDL.Codegen.Definitions

import Data.List
import Data.List.Elem
import Data.SOP
import Data.String
import Text.WebIDL.Codegen.Args
import Text.WebIDL.Codegen.Enum
import Text.WebIDL.Codegen.Members
import Text.WebIDL.Codegen.Rules
import Text.WebIDL.Codegen.Types
import public Text.WebIDL.Codegen.Util

--------------------------------------------------------------------------------
--          Imports
--------------------------------------------------------------------------------

defImports : CGDomain -> String
defImports d = #"""
               import JS
               import Web.Internal.\#{d.name}Prim
               import Web.Internal.Types
               """#

typeImports : String
typeImports = "import JS"

--------------------------------------------------------------------------------
--          Data Declarations
--------------------------------------------------------------------------------

extern : CGDomain -> String
extern d = fastUnlines [ section "Interfaces" $ exts ext name d.ifaces
                       , section "Dictionaries" $ exts extNoCast name d.dicts
                       , section "Mixins" $ exts extNoCast name d.mixins
                       , section "Callbacks" $ exts extNoCast name d.callbacks
                       ]
  where extNoCast : String -> String
        extNoCast s = #"""
                      export data \#{s} : Type where [external]

                      export
                      ToFFI \#{s} \#{s} where toFFI = id

                      export
                      FromFFI \#{s} \#{s} where fromFFI = Just
                      """#

        ext : String -> String
        ext s = extNoCast s ++ "\n\n" ++
                #"""
                export
                SafeCast \#{s} where
                  safeCast = unsafeCastOnPrototypeName "\#{s}"
                """#

        exts :  (f : String -> String)
             -> (a -> Identifier)
             -> List a
             -> List String
        exts f g = map (("\n" ++) . f) . sort . map (value . g)

--------------------------------------------------------------------------------
--          CallbackInterfaces
--------------------------------------------------------------------------------

cbacks : (CGCallback -> List String) -> CGDomain -> String
cbacks f = section "Callbacks" . map ns . sortBy (comparing name) . callbacks
  where ns : CGCallback -> String
        ns i = namespaced i.name (f i)

callbacks : CGDomain -> String
callbacks = cbacks go
  where go : CGCallback -> List String
        go cb = callback cb :: constants cb.constants

primCallbacks : CGDomain -> String
primCallbacks = cbacks (pure . primCallback)

--------------------------------------------------------------------------------
--          JSType
--------------------------------------------------------------------------------

jsTypes : List CGDomain -> String
jsTypes ds =
  let ifs  = sortBy (comparing name) (ds >>= ifaces)
      dics = sortBy (comparing name) (ds >>= dicts)
   in section "Inheritance" $
        map (\i => jsType i.name i.super) ifs ++
        map (\d => jsType d.name d.super) dics

--------------------------------------------------------------------------------
--          Interfaces
--------------------------------------------------------------------------------

ifaces' : (CGIface -> List String) -> CGDomain -> String
ifaces' f = section "Interfaces" . map ns . sortBy (comparing name) . ifaces
  where ns : CGIface -> String
        ns i = namespaced i.name (f i)

ifaces : CGDomain -> String
ifaces = ifaces' $ \(MkIface n s cs fs) => constants cs ++ functions fs

primIfaces : CGDomain -> String
primIfaces = ifaces' (primFunctions . functions)

--------------------------------------------------------------------------------
--          Dictionaries
--------------------------------------------------------------------------------

dicts' : (CGDict -> List String) -> CGDomain -> String
dicts' f = section "Dictionaries" . map ns . sortBy (comparing name) . dicts
  where ns : CGDict -> String
        ns d = namespaced d.name (f d)

dicts : CGDomain -> String
dicts = dicts' $ \(MkDict n s fs) => functions fs

primDicts : CGDomain -> String
primDicts = dicts' (primFunctions . functions)

--------------------------------------------------------------------------------
--          Mixins
--------------------------------------------------------------------------------

mixins' : (CGMixin -> List String) -> CGDomain -> String
mixins' f = section "Mixins" . map ns . sortBy (comparing name) . mixins
  where ns : CGMixin -> String
        ns m = namespaced m.name (f m)

mixins : CGDomain -> String
mixins = mixins' $ \(MkMixin n cs fs) => constants cs ++ functions fs

primMixins : CGDomain -> String
primMixins = mixins' (primFunctions . functions)

--------------------------------------------------------------------------------
--          Typedefs
--------------------------------------------------------------------------------

export
typedefs : List CGDomain -> String
typedefs ds =
      #"""
      module Web.Internal.Types

      import JS
      import public Web.Internal.AnimationTypes as Types
      import public Web.Internal.ClipboardTypes as Types
      import public Web.Internal.CssTypes as Types
      import public Web.Internal.DomTypes as Types
      import public Web.Internal.FetchTypes as Types
      import public Web.Internal.FileTypes as Types
      import public Web.Internal.GeometryTypes as Types
      import public Web.Internal.HtmlTypes as Types
      import public Web.Internal.MediasourceTypes as Types
      import public Web.Internal.MediastreamTypes as Types
      import public Web.Internal.PermissionsTypes as Types
      import public Web.Internal.ServiceworkerTypes as Types
      import public Web.Internal.StreamsTypes as Types
      import public Web.Internal.SvgTypes as Types
      import public Web.Internal.UIEventsTypes as Types
      import public Web.Internal.UrlTypes as Types
      import public Web.Internal.VisibilityTypes as Types
      import public Web.Internal.WebglTypes as Types
      import public Web.Internal.WebidlTypes as Types
      import public Web.Internal.XhrTypes as Types

      %default total
      """# ++ "\n\n" ++ jsTypes ds

--------------------------------------------------------------------------------
--          Codegen
--------------------------------------------------------------------------------
--
export
types : CGDomain -> String
types d =
  #"""
  module Web.Internal.\#{d.name}Types

  \#{typeImports}

  %default total

  \#{enums d.enums}
  \#{extern d}
  """#

export
primitives : CGDomain -> String
primitives d =
  #"""
  module Web.Internal.\#{d.name}Prim

  import JS
  import Web.Internal.Types

  %default total

  \#{primIfaces d}
  \#{primMixins d}
  \#{primDicts d}
  \#{primCallbacks d}
  """#

export
definitions : CGDomain -> String
definitions d =
  #"""
  module Web.Raw.\#{d.name}

  \#{defImports d}

  %default total

  \#{Definitions.ifaces d}
  \#{Definitions.mixins d}
  \#{Definitions.dicts d}
  \#{Definitions.callbacks d}
  """#
