module verilang::Main

// Main entry point for VeriLang (Project 4).
// Parses .vl files, runs the type checker, and displays results.

import verilang::Syntax;
import verilang::AST;
import verilang::Parser;
import verilang::Interpreter;
import verilang::TypeChecker;
import IO;
import ParseTree;

void run(loc file) {
  println("=== Step 1: Parsing <file> ===");
  Program prog;
  try {
    prog = loadProgram(file);
    println("✓ Parse OK");
  } catch e: {
    println("✗ Parse failed: <e>");
    return;
  }

  println("\n=== Step 2: Type checking ===");
  list[TypeError] errors = checkProgram(prog);
  printErrors(errors);

  int errorCount = size([e | e <- errors, typeError(_) := e]);
  if (errorCount > 0) {
    println("\n✗ Refusing to run program with type errors.");
  } else {
    println("\n=== Step 3: Running program ===");
    runProgram(prog);
  }
}

void testSet()   { run(|project://VeriLang4/examples/Set.vl|); }
void testTypes() { run(|project://VeriLang4/examples/TypeTest.vl|); }
