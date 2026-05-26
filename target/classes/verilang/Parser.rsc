module verilang::Parser

import verilang::Syntax;
import verilang::AST;
import ParseTree;
import IO;
import String;

// ─── Public parsing API ───────────────────────────────────────────────────────

// Parse a VeriLang source string and return the parse tree
public Tree parseVeriLang(str source) {
  return parse(#start[Program], source, allowAmbiguity=false);
}

// Parse a VeriLang file (.vl) and return the parse tree
public Tree parseVeriLangFile(loc file) {
  str src = readFile(file);
  return parse(#start[Program], src, allowAmbiguity=false);
}

// Parse a .vl file and return the AST
public Program loadProgram(loc file) {
  Tree t = parseVeriLangFile(file);
  return implodeProgram(t);
}

// Parse a string and return the AST
public Program parseProgram(str source) {
  Tree t = parseVeriLang(source);
  return implodeProgram(t);
}

// ─── Manual imploder (tree → AST) ────────────────────────────────────────────
// We write this manually because constructor names don't always match labels.

public Program implodeProgram(Tree t) {
  if ((start[Program]) `<Program p>` := t)
    return implodeProgram2(p);
  throw "Expected start[Program], got: <t>";
}

Program implodeProgram2((Program) `<Module m>`) = program(implodeModule(m));

Module implodeModule((Module) `defmodule <Identifier name> <Imports? imp> <Body body> end`) =
  \module("<name>",
          imp has top ? implodeImports(imp.top) : [],
          implodeBody(body));

// ─── Imports ─────────────────────────────────────────────────────────────────
list[Import] implodeImports(Imports imports) {
  list[Import] imps = [];
  visit(imports) {
    case Import i: imps += [implodeImport(i)];
  }
  return imps;
}

Import implodeImport((Import) `using <Identifier name>`) = \import("<name>");

// ─── Body ─────────────────────────────────────────────────────────────────────
list[BodyDecl] implodeBody(Body body) {
  list[BodyDecl] decls = [];
  visit(body) {
    case Space s:         decls += [implodeSpace(s)];
    case OperatorDef op:  decls += [implodeOperator(op)];
    case VarBlock v:      decls += [implodeVarBlock(v)];
    case RuleDef r:       decls += [implodeRule(r)];
    case ExpressionDef e: decls += [implodeExpressionDef(e)];
  }
  return decls;
}

BodyDecl implodeBodyDecl((BodyDecl) `<Space s>`)         = implodeSpace(s);
BodyDecl implodeBodyDecl((BodyDecl) `<OperatorDef opDef>`) = implodeOperator(opDef);
BodyDecl implodeBodyDecl((BodyDecl) `<VarBlock v>`)      = implodeVarBlock(v);
BodyDecl implodeBodyDecl((BodyDecl) `<RuleDef r>`)       = implodeRule(r);
BodyDecl implodeBodyDecl((BodyDecl) `<ExpressionDef e>`) = implodeExpressionDef(e);

// ─── Space ────────────────────────────────────────────────────────────────────
BodyDecl implodeSpace((Space) `defspace <Identifier name> <SubSpace? sub> end`) =
  space("<name>",
        sub has top ? ["<sub.top.\Identifier>"] : []);

// ─── Operators ────────────────────────────────────────────────────────────────
BodyDecl implodeOperator((OperatorDef) `defoperator <Identifier name> : <CurryingNotation curry> <Attributes? attrs> end`) =
  operatorDef("<name>",
              implodeCurrying(curry),
              attrs has top ? implodeAttributes(attrs.top) : []);

list[VeriType] implodeCurrying((CurryingNotation) `<{TypeRef "-\>"}+ types>`) =
  [implodeTypeRef(t) | TypeRef t <- types];

VeriType implodeTypeRef((TypeRef) `<Type tp>`) = implodeType(tp);

VeriType implodeType((Type) `<Identifier id>`) {
  switch ("<id>") {
    case "Int":    return typeInt();
    case "Bool":   return typeBool();
    case "Char":   return typeChar();
    case "String": return typeString();
    default:       return typeUser("<id>");
  }
}

// ─── Variables ────────────────────────────────────────────────────────────────
BodyDecl implodeVarBlock(VarBlock block) {
  list[VarDef] defs = [];
  visit(block) {
    case VarDef d: defs += [implodeVarDef(d)];
  }
  return varBlock(defs);
}

VarDef implodeVarDef((VarDef) `<Identifier name> : <Type tp>`) =
  varDef("<name>", implodeType(tp));

// ─── Rules ────────────────────────────────────────────────────────────────────
BodyDecl implodeRule((RuleDef) `defrule <OpApplication lhs> -\> <OpApplication rhs> end`) =
  ruleDef(implodeOpApp(lhs), implodeOpApp(rhs));

// ─── Expressions ─────────────────────────────────────────────────────────────
BodyDecl implodeExpressionDef((ExpressionDef) `defexpression <Expression expr> <Attributes? attrs> end`) =
  expressionDecl(implodeExpression(expr),
                 attrs has top ? implodeAttributes(attrs.top) : []);

Expression implodeExpression((Expression) `<QuantExpr q>`) = implodeQuant(q);
Expression implodeExpression((Expression) `<OrExpr e>`)    = implodeOrExpr(e);

Expression implodeQuant((QuantExpr) `forall <Identifier v> in <Identifier sp> . <Expression body>`) =
  forall("<v>", "<sp>", implodeExpression(body));
Expression implodeQuant((QuantExpr) `exists <Identifier v> in <Identifier sp> . <Expression body>`) =
  exists("<v>", "<sp>", implodeExpression(body));

Expression implodeOrExpr((OrExpr) `<OrExpr l> or <AndExpr r>`)  = binOp(implodeOrExpr(l), orOp(), implodeAndExpr(r));
Expression implodeOrExpr((OrExpr) `<OrExpr l> ≡ <AndExpr r>`)   = binOp(implodeOrExpr(l), equivOp(), implodeAndExpr(r));
Expression implodeOrExpr((OrExpr) `<OrExpr l> =\> <AndExpr r>`) = binOp(implodeOrExpr(l), impliesOp(), implodeAndExpr(r));
Expression implodeOrExpr((OrExpr) `<AndExpr e>`) = implodeAndExpr(e);

Expression implodeAndExpr((AndExpr) `<AndExpr l> and <NegExpr r>`) = binOp(implodeAndExpr(l), andOp(), implodeNegExpr(r));
Expression implodeAndExpr((AndExpr) `<NegExpr e>`) = implodeNegExpr(e);

Expression implodeNegExpr((NegExpr) `neg <NegExpr e>`) = negExpr(implodeNegExpr(e));
Expression implodeNegExpr((NegExpr) `<CmpExpr e>`) = implodeCmpExpr(e);

Expression implodeCmpExpr((CmpExpr) `<CmpExpr l> = <AddExpr r>`)   = binOp(implodeCmpExpr(l), eqOp(),  implodeAddExpr(r));
Expression implodeCmpExpr((CmpExpr) `<CmpExpr l> \< <AddExpr r>`)  = binOp(implodeCmpExpr(l), ltOp(),  implodeAddExpr(r));
Expression implodeCmpExpr((CmpExpr) `<CmpExpr l> \> <AddExpr r>`)  = binOp(implodeCmpExpr(l), gtOp(),  implodeAddExpr(r));
Expression implodeCmpExpr((CmpExpr) `<CmpExpr l> \<= <AddExpr r>`) = binOp(implodeCmpExpr(l), leqOp(), implodeAddExpr(r));
Expression implodeCmpExpr((CmpExpr) `<CmpExpr l> \>= <AddExpr r>`) = binOp(implodeCmpExpr(l), geqOp(), implodeAddExpr(r));
Expression implodeCmpExpr((CmpExpr) `<CmpExpr l> \<\> <AddExpr r>`)= binOp(implodeCmpExpr(l), neqOp(), implodeAddExpr(r));
Expression implodeCmpExpr((CmpExpr) `<AddExpr e>`) = implodeAddExpr(e);

Expression implodeAddExpr((AddExpr) `<AddExpr l> + <MulExpr r>`) = binOp(implodeAddExpr(l), addOp(), implodeMulExpr(r));
Expression implodeAddExpr((AddExpr) `<AddExpr l> - <MulExpr r>`) = binOp(implodeAddExpr(l), subOp(), implodeMulExpr(r));
Expression implodeAddExpr((AddExpr) `<MulExpr e>`) = implodeMulExpr(e);

Expression implodeMulExpr((MulExpr) `<MulExpr l> ** <UnaryExpr r>`) = binOp(implodeMulExpr(l), powOp(), implodeUnary(r));
Expression implodeMulExpr((MulExpr) `<MulExpr l> * <UnaryExpr r>`)  = binOp(implodeMulExpr(l), mulOp(), implodeUnary(r));
Expression implodeMulExpr((MulExpr) `<MulExpr l> / <UnaryExpr r>`)  = binOp(implodeMulExpr(l), divOp(), implodeUnary(r));
Expression implodeMulExpr((MulExpr) `<MulExpr l> % <UnaryExpr r>`)  = binOp(implodeMulExpr(l), modOp(), implodeUnary(r));
Expression implodeMulExpr((MulExpr) `<UnaryExpr e>`) = implodeUnary(e);

Expression implodeUnary((UnaryExpr) `- <UnaryExpr e>`) = unaryMinus(implodeUnary(e));
Expression implodeUnary((UnaryExpr) `<Primary p>`)     = implodePrimary(p);

Expression implodePrimary((Primary) `( <Expression e> )`) = implodeExpression(e);
Expression implodePrimary((Primary) `<OpApplication a>`)  = opApp(implodeOpApp(a));
Expression implodePrimary((Primary) `<Identifier id>`)    = idExpr("<id>");
Expression implodePrimary((Primary) `<Literal lit>`)      = litExpr(implodeLiteral(lit));

// ─── OpApplication ────────────────────────────────────────────────────────────
OpApplication implodeOpApp((OpApplication) `( <Identifier name> <Arg* args> )`) =
  applyOp("<name>", [implodeArg(a) | Arg a <- args]);

Expression implodeArg((Arg) `<Primary p>`) = implodePrimary(p);

// ─── Attributes ──────────────────────────────────────────────────────────────
list[Attribute] implodeAttributes((Attributes) `[ <AttrItem+ items> ]`) =
  [implodeAttrItem(i) | AttrItem i <- items];

Attribute implodeAttrItem((AttrItem) `<Identifier key>`) = attrKey("<key>");
Attribute implodeAttrItem((AttrItem) `<Identifier key> : <AttrVal v>`) = attr("<key>", implodeAttrVal(v));

AttrVal implodeAttrVal((AttrVal) `<Identifier id>`)  = attrId("<id>");
AttrVal implodeAttrVal((AttrVal) `<Literal lit>`)    = attrLit(implodeLiteral(lit));

// ─── Literals ────────────────────────────────────────────────────────────────
Literal implodeLiteral((Literal) `<IntLit n>`)  = intLit(toInt("<n>"));
Literal implodeLiteral((Literal) `<StrLit s>`)  {
  str raw = "<s>";
  return strLit(substring(raw, 1, size(raw)-1));
}
Literal implodeLiteral((Literal) `<CharLit c>`) {
  str raw = "<c>";
  return charLit(substring(raw, 1, size(raw)-1));
}
Literal implodeLiteral((Literal) `<NullVal _>`) = nullLit();
