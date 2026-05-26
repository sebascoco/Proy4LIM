module verilang::Syntax

// ─── Keywords ────────────────────────────────────────────────────────────────
keyword Keywords
  = "defmodule" | "using"        | "defspace"     | "defoperator"
  | "defvar"    | "defrule"      | "defexpression" | "end"
  | "forall"    | "exists"       | "in"            | "and"
  | "or"        | "neg"          | "defer"         | "True"
  | "False"     | "None"
  // ── new type keywords (Project 3) ──────────────────────────────────────────
  | "Int"       | "Bool"         | "Char"          | "String"
  ;

// ─── Layout ──────────────────────────────────────────────────────────────────
extend lang::std::Layout;

// ─── Lexical rules ───────────────────────────────────────────────────────────
lexical Letter = [a-zA-Z];
lexical Digit  = [0-9];
lexical Char   = Letter | Digit | "-";

lexical Identifier
  = Letter Char* !>> (Letter | Digit | "-") \ Keywords;

lexical IntLit   = Digit+;
lexical BoolLit  = "True" | "False" | "None";
lexical StrLit   = "\"" ![\"]* "\"";
lexical CharLit  = "\'" ![\'¸]  "\'";
lexical NullVal  = "ø" | "∅";

// ─── Type annotations (Project 3) ────────────────────────────────────────────
// FIX (Project 4): @category annotations moved off of alternatives to avoid
// parse errors in older Rascal versions. The syntax is kept, categories removed.
syntax Type
  = "Int"
  | "Bool"
  | "Char"
  | "String"
  | Identifier   // user-defined type (space name)
  ;

// ─── Start symbol ────────────────────────────────────────────────────────────
start syntax Program = Module;

// ─── Module ──────────────────────────────────────────────────────────────────
syntax Module
  = "defmodule" Identifier Imports? Body "end";

syntax Imports
  = Import+;

syntax Import
  = "using" Identifier;

syntax Body
  = BodyDecl*;

syntax BodyDecl
  = Space
  | OperatorDef
  | VarBlock
  | RuleDef
  | ExpressionDef
  ;

// ─── Spaces ──────────────────────────────────────────────────────────────────
syntax Space
  = "defspace" Identifier SubSpace? "end";

syntax SubSpace
  = "\<" Identifier;

// ─── Operators ───────────────────────────────────────────────────────────────
syntax OperatorDef
  = "defoperator" Identifier ":" CurryingNotation Attributes? "end";

syntax CurryingNotation
  = TypeRef "-\>" TypeRef ("-\>" TypeRef)*;

syntax TypeRef
  = Type;

// ─── Variables ───────────────────────────────────────────────────────────────
syntax VarBlock
  = "defvar" {VarDef " "}+ "end";

syntax VarDef
  = Identifier ":" Type;

// ─── Rules ───────────────────────────────────────────────────────────────────
syntax RuleDef
  = "defrule" OpApplication "-\>" OpApplication "end";

// ─── Expressions ─────────────────────────────────────────────────────────────
syntax ExpressionDef
  = "defexpression" Expression Attributes? "end";

syntax Expression
  = QuantExpr
  | OrExpr
  ;

syntax QuantExpr
  = "forall" Identifier "in" Identifier "." Expression
  | "exists" Identifier "in" Identifier "." Expression
  ;

// Precedence: ≡ => < or < and < neg < comparison < arithmetic < atom
syntax OrExpr
  = left  OrExpr "or"  AndExpr
  | left  OrExpr "≡"   AndExpr
  | left  OrExpr "=\>" AndExpr
  |       AndExpr
  ;

syntax AndExpr
  = left AndExpr "and" NegExpr
  |      NegExpr
  ;

syntax NegExpr
  = "neg" NegExpr
  | CmpExpr
  ;

syntax CmpExpr
  = left CmpExpr "="    AddExpr
  | left CmpExpr "\<"   AddExpr
  | left CmpExpr "\>"   AddExpr
  | left CmpExpr "\<="  AddExpr
  | left CmpExpr "\>="  AddExpr
  | left CmpExpr "\<\>" AddExpr
  |      AddExpr
  ;

syntax AddExpr
  = left AddExpr "+" MulExpr
  | left AddExpr "-" MulExpr
  |      MulExpr
  ;

syntax MulExpr
  = left MulExpr "*"  UnaryExpr
  | left MulExpr "/"  UnaryExpr
  | left MulExpr "**" UnaryExpr
  | left MulExpr "%"  UnaryExpr
  |      UnaryExpr
  ;

syntax UnaryExpr
  = "-" UnaryExpr
  | Primary
  ;

syntax Primary
  = "(" Expression ")"
  | OpApplication
  | Identifier !>> (Letter | Digit | "-")
  | Literal
  ;

// ─── Operator application ─────────────────────────────────────────────────────
syntax OpApplication
  = "(" Identifier Arg* ")";

syntax Arg
  = Primary;

// ─── Attributes ──────────────────────────────────────────────────────────────
syntax Attributes
  = "[" {AttrItem " "}+ "]";

syntax AttrItem
  = Identifier (":" AttrVal)?;

syntax AttrVal
  = Identifier
  | Literal
  ;

// ─── Literals ────────────────────────────────────────────────────────────────
syntax Literal
  = intLit:  IntLit
  | boolLit: BoolLit
  | strLit:  StrLit
  | charLit: CharLit
  | nullLit: NullVal
  ;
