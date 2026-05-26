module verilang::RunnerJson

import verilang::Syntax;
import verilang::AST;
import verilang::Parser;
import verilang::Interpreter;
import verilang::TypeChecker;
import ParseTree;
import Message;
import IO;
import Set;
import List;
import String;

// ─── JSON utilities ───────────────────────────────────────────────────────────

str esc(str s) =
    replaceAll(replaceAll(replaceAll(replaceAll(
        s, "\\", "\\\\"), "\"", "\\\""), "\n", "\\n"), "\t", "\\t");

str jsonArr(list[str] items) =
    "[<intercalate(", ", [ "\"<esc(i)>\"" | i <- items ])>]";

str jsonResult(
    bool success,
    str modName,
    bool parseOk,
    bool tcOk,
    bool semOk,
    list[str] tcErrs,
    list[str] semErrs,
    list[str] output,
    str err,
    str codigoFormateado,
    str resumen
) =
    "{\"success\":<success>,"
    + "\"module\":\"<esc(modName)>\","
    + "\"parseOk\":<parseOk>,"
    + "\"typeCheckOk\":<tcOk>,"
    + "\"semanticOk\":<semOk>,"
    + "\"typeErrors\":<jsonArr(tcErrs)>,"
    + "\"semanticErrors\":<jsonArr(semErrs)>,"
    + "\"output\":<jsonArr(output)>,"
    + "\"error\":\"<esc(err)>\","
    + "\"codigoFormateado\":\"<esc(codigoFormateado)>\","
    + "\"resumen\":\"<esc(resumen)>\"}";

// ─── AST summary builder ─────────────────────────────────────────────────────

str summarizeModule(Module m) {
    list[str] lines = ["Module: <m.name>"];

    if (!isEmpty(m.imports))
        lines += ["Imports: <intercalate(", ", [ i.moduleName | i <- m.imports ])>"];

    list[str] spaces  = [ d.name | d <- m.body, space(_, _)       := d ];
    list[str] ops     = [ d.name | d <- m.body, operatorDef(_, _, _) := d ];
    list[str] rules   = [ "defrule" | d <- m.body, ruleDef(_, _)  := d ];
    list[str] exprs   = [ "defexpression" | d <- m.body, expressionDecl(_, _) := d ];

    int varCount = 0;
    for (d <- m.body) {
        if (varBlock(list[VarDef] defs) := d) varCount += size(defs);
    }

    if (!isEmpty(spaces)) lines += ["Spaces (<size(spaces)>): <intercalate(", ", spaces)>"];
    if (!isEmpty(ops))    lines += ["Operators (<size(ops)>): <intercalate(", ", ops)>"];
    if (varCount > 0)     lines += ["Variables: <varCount>"];
    if (!isEmpty(rules))  lines += ["Rules: <size(rules)>"];
    if (!isEmpty(exprs))  lines += ["Expressions: <size(exprs)>"];

    return intercalate("\\n", lines);
}

// ─── Interpreter output capture ───────────────────────────────────────────────

list[str] collectOutput(Program prog) {
    list[str] out = [];
    Module m = prog.m;
    out += ["Module: <m.name>"];
    for (Import imp <- m.imports)
        out += ["  uses: <imp.moduleName>"];

    for (BodyDecl d <- m.body) {
        switch (d) {
            case space(str name, list[str] subs): {
                if (isEmpty(subs))
                    out += ["Space: <name>"];
                else
                    out += ["Space: <name> < <intercalate(", ", subs)>"];
            }
            case operatorDef(str name, list[VeriType] sig, _): {
                list[str] ts = [ showVeriType(t) | t <- sig ];
                out += ["Operator: <name> : <intercalate(" -> ", ts)>"];
            }
            case varBlock(list[VarDef] defs): {
                for (varDef(str vn, VeriType vt) <- defs)
                    out += ["Var: <vn> : <showVeriType(vt)>"];
            }
            case ruleDef(applyOp(str lOp, _), applyOp(str rOp, _)):
                out += ["Rule: (<lOp> ...) -> (<rOp> ...)"];
            case expressionDecl(Expression expr, _):
                out += ["Expression: <showExpr(expr)>"];
        }
    }
    return out;
}

str showVeriType(typeInt())       = "Int";
str showVeriType(typeBool())      = "Bool";
str showVeriType(typeChar())      = "Char";
str showVeriType(typeString())    = "String";
str showVeriType(typeUser(str n)) = n;

str showExpr(forall(str v, str sp, Expression body)) = "forall <v> in <sp> . <showExpr(body)>";
str showExpr(exists(str v, str sp, Expression body)) = "exists <v> in <sp> . <showExpr(body)>";
str showExpr(binOp(Expression l, BinOp op, Expression r)) = "(<showExpr(l)> <showOp(op)> <showExpr(r)>)";
str showExpr(negExpr(Expression e))    = "neg <showExpr(e)>";
str showExpr(unaryMinus(Expression e)) = "-<showExpr(e)>";
str showExpr(opApp(applyOp(str name, list[Expression] args))) =
    "(<name><intercalate("", [" <showExpr(a)>" | a <- args])>)";
str showExpr(idExpr(str name))  = name;
str showExpr(litExpr(intLit(int n)))    = "<n>";
str showExpr(litExpr(boolLit(true)))    = "True";
str showExpr(litExpr(boolLit(false)))   = "False";
str showExpr(litExpr(charLit(str c)))   = "\'<c>\'";
str showExpr(litExpr(strLit(str s)))    = "\"<s>\"";
str showExpr(litExpr(nullLit()))        = "∅";
default str showExpr(Expression _)     = "...";

str showOp(andOp())     = "and";
str showOp(orOp())      = "or";
str showOp(equivOp())   = "≡";
str showOp(impliesOp()) = "=>";
str showOp(eqOp())      = "=";
str showOp(ltOp())      = "<";
str showOp(gtOp())      = ">";
str showOp(leqOp())     = "\<=";
str showOp(geqOp())     = "\>=";
str showOp(neqOp())     = "\<>";
str showOp(addOp())     = "+";
str showOp(subOp())     = "-";
str showOp(mulOp())     = "*";
str showOp(divOp())     = "/";
str showOp(powOp())     = "**";
str showOp(modOp())     = "%";

// ─── Main entry point ─────────────────────────────────────────────────────────

void main(list[str] args) {

    // 1. Read source file
    str src;
    try {
        loc file = isEmpty(args)
            ? |project://VeriLang4/examples/Set.vl|
            : (startsWith(args[0], "/") ? |file:///| + args[0] : |cwd:///| + args[0]);
        src = readFile(file);
    } catch e: {
        println(jsonResult(false, "", false, false, false, [], [], [],
                           "Could not read file: <e>", "", ""));
        return;
    }

    // 2. Parse
    Tree cst;
    try {
        cst = parse(#start[Program], src, allowAmbiguity=false);
    } catch ParseError(loc at): {
        println(jsonResult(false, "", false, false, false, [], [], [],
                           "Parse error at <at>", "", ""));
        return;
    } catch e: {
        println(jsonResult(false, "", false, false, false, [], [], [],
                           "Parse error: <e>", "", ""));
        return;
    }

    // 3. Build AST
    Program ast;
    try {
        ast = implodeProgram(cst);
    } catch e: {
        println(jsonResult(false, "", true, false, false, [], [], [],
                           "AST error: <e>", "", ""));
        return;
    }

    str modName = ast.m.name;
    str resumen = summarizeModule(ast.m);

    // 4. Type checking
    list[TypeError] tcResults;
    try {
        tcResults = checkProgram(ast);
    } catch e: {
        println(jsonResult(false, modName, true, false, false, [], [], [],
                           "Type checker error: <e>", "", resumen));
        return;
    }

    list[str] tcErrors   = [ msg | typeError(str msg)   <- tcResults ];
    list[str] tcWarnings = [ msg | typeWarning(str msg) <- tcResults ];
    // Combine warnings with errors for display; they go in typeErrors field
    list[str] allTcMsgs  = tcErrors + [ "WARNING: <w>" | w <- tcWarnings ];
    bool tcOk = isEmpty(tcErrors);

    if (!tcOk) {
        println(jsonResult(false, modName, true, false, false, allTcMsgs, [], [],
                           "", "", resumen));
        return;
    }

    // 5. Collect interpreter output
    list[str] output = [];
    try {
        output = collectOutput(ast);
    } catch e: {
        println(jsonResult(false, modName, true, true, true, allTcMsgs, [], [],
                           "Runtime error: <e>", "", resumen));
        return;
    }

    println(jsonResult(true, modName, true, true, true, allTcMsgs, [], output,
                       "", "", resumen));
}
