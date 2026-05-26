# VeriLang – Proyecto 4
## ISIS-2111 Elementos Esenciales de Lenguajes de Programación
**Autores:** Sebastián Salazar · Julián Pinto  
**Fecha:** Mayo 2026

---

## 1. Descripción general

Este proyecto extiende VeriLang (Proyecto 3) integrando la salida del lenguaje con una interfaz gráfica escrita en **Kotlin + Compose for Desktop**. La comunicación se hace a través de un archivo JSON generado por el módulo `verilang::RunnerJson` de Rascal, que el `LangService.kt` de Kotlin invoca como subproceso.

---

## 2. Correcciones del Proyecto 3

Se aplicaron las dos correcciones críticas indicadas en la rúbrica:

### 2.1 Anotaciones `@category` en alternativas de sintaxis
**Problema:** en la versión de Rascal del curso, las anotaciones `@category="..."` puestas *inline* dentro de alternativas de `syntax` causaban errores de parsing.

**Solución:** se eliminaron todas las anotaciones `@category` de las alternativas en `Syntax.rsc`. El comportamiento semántico del lenguaje no cambia; los colores del editor son una característica opcional.

### 2.2 Conflicto de nombres de campo en `AST.rsc`
**Problema:** el campo `val` se usaba tanto en `intLit(int val)` como en `boolLit(bool val)`, lo que produce un error de compilación porque Rascal no permite el mismo nombre de campo con tipos distintos en el mismo `data`.

**Solución:** se renombraron los campos:
- `intLit(int val)` → `intLit(int intVal)`
- `boolLit(bool val)` → `boolLit(bool boolVal)`
- `charLit(str val)` → `charLit(str charVal)`
- `strLit(str val)` → `strLit(str strVal)`

El `Parser.rsc` usa pattern matching con variables propias (e.g. `intLit(int n)`), por lo que **no requirió cambios**. El `TypeChecker.rsc` y el `Interpreter.rsc` tampoco acceden a los campos por nombre directamente.

---

## 3. Estructura del proyecto

```
VeriLang4/
├── META-INF/
│   └── RASCAL.MF                    ← Project-Name: VeriLang4
├── src/main/rascal/verilang/
│   ├── AST.rsc                      ← AST corregido (intVal/boolVal)
│   ├── Syntax.rsc                   ← Gramática corregida (sin @category inline)
│   ├── Parser.rsc                   ← Parser manual (sin cambios)
│   ├── TypeChecker.rsc              ← Type checker completo
│   ├── Interpreter.rsc              ← Intérprete
│   ├── Main.rsc                     ← Entry point Rascal (pruebas locales)
│   └── RunnerJson.rsc               ← Punto de entrada para Kotlin (nuevo)
├── examples/
│   ├── Set.vl
│   ├── TypeTest.vl
│   ├── TypeErrors.vl
│   ├── ElementExistenceTest.vl
│   └── ElementExistenceErrors.vl
├── kotlin-app/
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   └── src/main/kotlin/verilang/
│       ├── Main.kt                  ← Punto de entrada de la app
│       ├── model/RunResult.kt       ← Modelo JSON
│       ├── service/LangService.kt   ← Invocación de Rascal
│       └── ui/MainWindow.kt         ← Interfaz gráfica Compose
└── pom.xml
```

---

## 4. Módulo `RunnerJson.rsc`

Este módulo es el puente entre Rascal y Kotlin. Cuando Kotlin llama al jar de Rascal con el argumento `verilang::RunnerJson`, el módulo:

1. **Lee** el archivo `.vl` indicado por argumento.
2. **Parsea** el código con `parse(#start[Program], src)`.
3. **Construye el AST** con `implodeProgram(cst)`.
4. **Ejecuta el type checker** con `checkProgram(ast)`.
5. **Recopila la salida** (módulos, espacios, operadores, variables, reglas, expresiones).
6. **Imprime exactamente un objeto JSON** con la estructura que espera `RunResult.kt`.

El JSON producido tiene la forma:
```json
{
  "success": true,
  "module": "Set",
  "parseOk": true,
  "typeCheckOk": true,
  "semanticOk": true,
  "typeErrors": [],
  "semanticErrors": [],
  "output": ["Module: Set", "  uses: List", "Space: Set < SuperSet", ...],
  "error": "",
  "codigoFormateado": "",
  "resumen": "Module: Set\nImports: List\nSpaces (1): Set\nOperators (4): union, isIn, ..."
}
```

---

## 5. Interfaz gráfica Kotlin

La GUI muestra:

| Sección | Descripción |
|---------|-------------|
| **Estado del análisis** | Chips Parser / Type Check / Semántica (OK / FAIL) |
| **Módulos** | Nombre del módulo y sus imports |
| **Resumen del módulo** | Conteo de spaces, operators, variables, reglas, expresiones |
| **Estructura del programa** | Lista de todos los elementos definidos |
| **Errores de tipos** | Mensajes del TypeChecker (si los hay) |
| **Error general** | Excepciones de parsing u otros errores de Rascal |

---

## 6. Cómo ejecutar

### Prerrequisitos
- Java 11+
- Gradle instalado (`gradle --version`)
- El archivo `rascal-shell-stable.jar` en la raíz del proyecto (`VeriLang4/`)

### Pasos

```bash
# 1. Colocar rascal-shell-stable.jar en la raíz
cp rascal-shell-stable.jar VeriLang4/

# 2. Desde la carpeta kotlin-app
cd VeriLang4/kotlin-app
gradle run
```

La primera ejecución descarga dependencias (~2 min). Las siguientes son inmediatas.

### Prueba rápida desde Rascal (sin Kotlin)
Desde la consola de Rascal en Eclipse/VS Code:
```
import verilang::RunnerJson;
main(["/ruta/a/VeriLang4/examples/Set.vl"]);
```

---

## 7. Archivos de prueba

| Archivo | Propósito |
|---------|-----------|
| `Set.vl` | Módulo completo con spaces, operators, vars, rules, expressions |
| `TypeTest.vl` | Prueba de tipos correctos |
| `TypeErrors.vl` | Prueba que el type checker detecte errores |
| `ElementExistenceTest.vl` | Elementos existentes en atributos |
| `ElementExistenceErrors.vl` | Referencias a elementos inexistentes |
