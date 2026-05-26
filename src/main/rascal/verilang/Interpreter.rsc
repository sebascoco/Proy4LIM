module verilang::Interpreter

// Code generation / interpreter for VeriLang programs.
// Runs the program and shows results on the console (Task 2 of Project 3).

import verilang::AST;
import verilang::Parser;
import IO;
import List;
import Map;
import String;

// ─── Runtime environment ─────────────────────────────────────────────────────
alias Env = map[str, Value];

data Value
  = intVal(int n)
  | boolVal(bool b)
  | charVal(str c)
  | strVal(str s)
  | nullVal()
  | undefinedVal()
  ;

// ─── Entry points ─────────────────────────────────────────────────────────────

// Run a .vl file – print all results to console
void runFile(loc file) {
  println("=== Running VeriLang program: <file> ===");
  Program prog = loadProgram(file);
  runProgram(prog);
}

// Run from a source string
void runString(str source) {
  println("=== Running VeriLang program ===");
  Program prog = parseProgram(source);
  runProgram(prog);
}

void runProgram(Program prog) {
  Module m = prog.m;
  println("Module: <m.name>");
  for (Import imp <- m.imports) {
    println("  uses: <imp.moduleName>");
  }
  Env env = ();
  env = interpretBody(m.body, env);
  println("=== Done ===");
}

// ─── Body interpretation ─────────────────────────────────────────────────────
Env interpretBody(list[BodyDecl] decls, Env env) {
  for (BodyDecl d <- decls) {
    env = interpretDecl(d, env);
  }
  return env;
}

Env interpretDecl(space(str name, list[str] subs), Env env) {
  if (isEmpty(subs))
    println("Space: <name>");
  else
    println("Space: <name> \< <intercalate(", ", subs)>");
  return env;
}

Env interpretDecl(operatorDef(str name, list[VeriType] sig, list[Attribute] attrs), Env env) {
  str sigStr = intercalate(" -\> ", [showType(t) | VeriType t <- sig]);
  println("Operator: <name> : <sigStr>");
  if (!isEmpty(attrs)) {
    println("  Attributes: <showAttrs(attrs)>");
  }
  return env;
}

Env interpretDecl(varBlock(list[VarDef] defs), Env env) {
  for (varDef(str nm, VeriType tp) <- defs) {
    println("Variable: <nm> : <showType(tp)>");
    env[nm] = defaultValue(tp);
  }
  return env;
}

Env interpretDecl(ruleDef(OpApplication lhs, OpApplication rhs), Env env) {
  println("Rule: <showOpApp(lhs)> -\> <showOpApp(rhs)>");
  return env;
}

Env interpretDecl(expressionDecl(Expression expr, list[Attribute] attrs), Env env) {
  println("Expression: <showExpr(expr)>");
  Value v = evalExpr(expr, env);
  println("  =\> <showValue(v)>");
  return env;
}

// ─── Evaluator ────────────────────────────────────────────────────────────────
Value evalExpr(forall(str var, str sp, Expression body), Env env) {
  println("  (forall <var> in <sp> — symbolic, not evaluated)");
  return undefinedVal();
}

Value evalExpr(exists(str var, str sp, Expression body), Env env) {
  println("  (exists <var> in <sp> — symbolic, not evaluated)");
  return undefinedVal();
}

Value evalExpr(binOp(Expression l, BinOp op, Expression r), Env env) {
  Value lv = evalExpr(l, env);
  Value rv = evalExpr(r, env);
  return evalBinOp(op, lv, rv);
}

Value evalExpr(negExpr(Expression e), Env env) {
  Value v = evalExpr(e, env);
  if (boolVal(bool b) := v) return boolVal(!b);
  return undefinedVal();
}

Value evalExpr(unaryMinus(Expression e), Env env) {
  Value v = evalExpr(e, env);
  if (intVal(int n) := v) return intVal(-n);
  return undefinedVal();
}

Value evalExpr(opApp(OpApplication app), Env env) = evalOpApp(app, env);

Value evalExpr(idExpr(str name), Env env) {
  if (name in env) return env[name];
  return undefinedVal();
}

Value evalExpr(litExpr(Literal lit), Env _) = evalLit(lit);

Value evalLit(intLit(int n))    = intVal(n);
Value evalLit(boolLit(bool b))  = boolVal(b);
Value evalLit(charLit(str c))   = charVal(c);
Value evalLit(strLit(str s))    = strVal(s);
Value evalLit(nullLit())        = nullVal();

Value evalOpApp(applyOp(str name, list[Expression] args), Env env) {
  list[Value] argVals = [evalExpr(a, env) | Expression a <- args];
  // Built-in handling for known operators
  switch(name) {
    case "neg":
      if (size(argVals) == 1, boolVal(bool b) := argVals[0]) return boolVal(!b);
    case "disjunction":
      if (size(argVals) == 2, boolVal(bool a) := argVals[0], boolVal(bool b) := argVals[1]) return boolVal(a || b);
    case "conjunction":
      if (size(argVals) == 2, boolVal(bool a) := argVals[0], boolVal(bool b) := argVals[1]) return boolVal(a && b);
    case "implication":
      if (size(argVals) == 2, boolVal(bool a) := argVals[0], boolVal(bool b) := argVals[1]) return boolVal(!a || b);
    default: ;
  }
  return undefinedVal();
}

Value evalBinOp(andOp(),     boolVal(bool a), boolVal(bool b)) = boolVal(a && b);
Value evalBinOp(orOp(),      boolVal(bool a), boolVal(bool b)) = boolVal(a || b);
Value evalBinOp(equivOp(),   boolVal(bool a), boolVal(bool b)) = boolVal(a == b);
Value evalBinOp(impliesOp(), boolVal(bool a), boolVal(bool b)) = boolVal(!a || b);
Value evalBinOp(eqOp(),  intVal(int a), intVal(int b)) = boolVal(a == b);
Value evalBinOp(ltOp(),  intVal(int a), intVal(int b)) = boolVal(a < b);
Value evalBinOp(gtOp(),  intVal(int a), intVal(int b)) = boolVal(a > b);
Value evalBinOp(leqOp(), intVal(int a), intVal(int b)) = boolVal(a <= b);
Value evalBinOp(geqOp(), intVal(int a), intVal(int b)) = boolVal(a >= b);
Value evalBinOp(neqOp(), intVal(int a), intVal(int b)) = boolVal(a != b);
Value evalBinOp(addOp(), intVal(int a), intVal(int b)) = intVal(a + b);
Value evalBinOp(subOp(), intVal(int a), intVal(int b)) = intVal(a - b);
Value evalBinOp(mulOp(), intVal(int a), intVal(int b)) = intVal(a * b);
Value evalBinOp(divOp(), intVal(int a), intVal(int b)) = intVal(a / b);
Value evalBinOp(modOp(), intVal(int a), intVal(int b)) = intVal(a % b);
default Value evalBinOp(BinOp _, Value _, Value _) = undefinedVal();

// ─── Helpers ─────────────────────────────────────────────────────────────────
str showType(typeInt())        = "Int";
str showType(typeBool())       = "Bool";
str showType(typeChar())       = "Char";
str showType(typeString())     = "String";
str showType(typeUser(str n))  = n;

str showValue(intVal(int n))   = "<n>";
str showValue(boolVal(true))   = "True";
str showValue(boolVal(false))  = "False";
str showValue(charVal(str c))  = "\'<c>\'";
str showValue(strVal(str s))   = "\"<s>\"";
str showValue(nullVal())       = "null";
str showValue(undefinedVal())  = "(symbolic)";

str showOpApp(applyOp(str name, list[Expression] args)) =
  "(<name> <intercalate(" ", [showExpr(a) | Expression a <- args])>)";

str showExpr(forall(str v, str sp, Expression b)) = "forall <v> in <sp> . <showExpr(b)>";
str showExpr(exists(str v, str sp, Expression b)) = "exists <v> in <sp> . <showExpr(b)>";
str showExpr(binOp(Expression l, BinOp op, Expression r)) = "(<showExpr(l)> <showBinOp(op)> <showExpr(r)>)";
str showExpr(negExpr(Expression e)) = "neg <showExpr(e)>";
str showExpr(unaryMinus(Expression e)) = "-<showExpr(e)>";
str showExpr(opApp(OpApplication a)) = showOpApp(a);
str showExpr(idExpr(str n)) = n;
str showExpr(litExpr(Literal lit)) = showLit(lit);

str showLit(intLit(int n))   = "<n>";
str showLit(boolLit(true))   = "True";
str showLit(boolLit(false))  = "False";
str showLit(charLit(str c))  = "\'<c>\'";
str showLit(strLit(str s))   = "\"<s>\"";
str showLit(nullLit())       = "null";

str showBinOp(andOp())     = "and";
str showBinOp(orOp())      = "or";
str showBinOp(equivOp())   = "≡";
str showBinOp(impliesOp()) = "=\>";
str showBinOp(eqOp())      = "=";
str showBinOp(ltOp())      = "\<";
str showBinOp(gtOp())      = "\>";
str showBinOp(leqOp())     = "\<=";
str showBinOp(geqOp())     = "\>=";
str showBinOp(neqOp())     = "\<\>";
str showBinOp(addOp())     = "+";
str showBinOp(subOp())     = "-";
str showBinOp(mulOp())     = "*";
str showBinOp(divOp())     = "/";
str showBinOp(powOp())     = "**";
str showBinOp(modOp())     = "%";

str showAttrs(list[Attribute] attrs) =
  intercalate(" ", [showAttr(a) | Attribute a <- attrs]);

str showAttr(attrKey(str k)) = k;
str showAttr(attr(str k, attrId(str v)))  = "<k>:<v>";
str showAttr(attr(str k, attrLit(Literal lit))) = "<k>:<showLit(lit)>";

Value defaultValue(typeInt())    = intVal(0);
Value defaultValue(typeBool())   = boolVal(false);
Value defaultValue(typeChar())   = charVal(" ");
Value defaultValue(typeString()) = strVal("");
Value defaultValue(typeUser(_))  = undefinedVal();
