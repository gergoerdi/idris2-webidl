module Text.WebIDL.Parser

import Text.Lexer
import Text.Parser
import Text.WebIDL.Identifier
import Text.WebIDL.Lexer

import Generics.Derive

%language ElabReflection

public export
IdlGrammarAny : (b : Bool) -> Type -> Type
IdlGrammarAny b t = Grammar (TokenData IdlToken) b t

public export
IdlGrammar : Type -> Type
IdlGrammar = IdlGrammarAny True

public export
IdlGrammar' : Type -> Type
IdlGrammar' = IdlGrammarAny False

tok : String -> (IdlToken -> Maybe a) -> IdlGrammar a
tok s f = terminal s (f . tok)

symbol : String -> IdlGrammar ()
symbol s = tok ("Symbol " ++ s) \case Other v => guard (s == v)
                                      _       => Nothing

comma : IdlGrammar ()
comma = symbol ","

--------------------------------------------------------------------------------
--          Identifiers
--------------------------------------------------------------------------------

export
ident : IdlGrammar Identifier
ident = tok "identifier" \case Ident i => Just i
                               _       => Nothing

||| IdentifierList :: identifier Identifiers
||| Identifiers :: , identifier Identifiers ε
export
identifierList : IdlGrammar (List1 Identifier)
identifierList = [| ident ::: many (comma *> ident) |]

--------------------------------------------------------------------------------
--          Parsing WebIDL
--------------------------------------------------------------------------------

public export
data Err : Type where 
  LexErr     : (msg : String) -> Err
  NoEOI      : (line : Int) -> (col : Int) -> (tok : IdlToken) -> Err
  ParseErr   :  (msg : String) -> Err
  ParseErrAt :  (msg : String)
             -> (line : Int)
             -> (col : Int)
             -> (tok : IdlToken)
             -> Err

%runElab derive "Text.WebIDL.Parser.Err" [Generic,Meta,Eq,Show]

toParseErr : ParseError (TokenData IdlToken) -> Err
toParseErr (Error x []) = ParseErr x
toParseErr (Error x (MkToken l c t :: _)) = ParseErrAt x l c t

export
parseIdl : IdlGrammar a -> String -> Either Err a
parseIdl g s = do ts <- mapFst LexErr (lexIdlNoNoise s)
                  (res,Nil) <- mapFst toParseErr (parse g ts)
                    | (_,MkToken l c t :: _) => Left (NoEOI l c t)
                  pure res