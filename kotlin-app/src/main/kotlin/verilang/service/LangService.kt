package verilang.service

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import verilang.model.RunResult
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Invokes Rascal as a subprocess and returns the parsed RunResult.
 *
 * Expected project layout:
 *
 *   VeriLang4/
 *   ├── rascal-shell-stable.jar
 *   ├── META-INF/RASCAL.MF
 *   ├── src/main/rascal/verilang/
 *   │   ├── AST.rsc
 *   │   ├── Syntax.rsc
 *   │   ├── Parser.rsc
 *   │   ├── Interpreter.rsc
 *   │   ├── TypeChecker.rsc
 *   │   └── RunnerJson.rsc
 *   ├── examples/
 *   └── kotlin-app/        ← this app runs from here
 */
class LangService {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    // The app runs from kotlin-app/; project root is one level up
    private val projectRoot: File by lazy {
        val cwd = File(System.getProperty("user.dir"))
        val candidate = cwd.resolve("../rascal-shell-stable.jar")
        if (candidate.exists()) cwd.resolve("..").canonicalFile
        else {
            val alt = cwd.parentFile
            if (alt?.resolve("rascal-shell-stable.jar")?.exists() == true) alt
            else cwd.resolve("..").canonicalFile
        }
    }

    private val rascalJar: File get() = projectRoot.resolve("rascal-shell-stable.jar")
    private val srcDir: File    get() = projectRoot.resolve("src")

    /** Run a VeriLang (.vl) file and return the analysis result. */
    suspend fun run(filePath: String): RunResult = withContext(Dispatchers.IO) {
        try {
            println("[VeriLangService] Running Rascal...")
            println("[VeriLangService] file    : $filePath")
            println("[VeriLangService] jar     : ${rascalJar.absolutePath}")
            println("[VeriLangService] src     : ${srcDir.absolutePath}")

            val t0 = System.currentTimeMillis()
            val output = executeRascal(filePath)
            println("[VeriLangService] time    : ${System.currentTimeMillis() - t0} ms")
            println("[VeriLangService] stdout  : ${output.length} chars")

            val jsonStr = extractJson(output)
            if (jsonStr == null) {
                println("[VeriLangService] ERROR: no JSON found in Rascal output")
                return@withContext RunResult(error = "Rascal did not produce valid JSON:\n$output")
            }

            json.decodeFromString<RunResult>(jsonStr)
        } catch (e: Exception) {
            println("[VeriLangService] exception: ${e.message}")
            e.printStackTrace()
            RunResult(error = e.message ?: "Unknown error")
        }
    }

    private fun executeRascal(filePath: String): String {
        if (!rascalJar.exists())
            throw RuntimeException("rascal-shell-stable.jar not found at: ${rascalJar.absolutePath}")
        if (!srcDir.exists())
            throw RuntimeException("src/ directory not found at: ${srcDir.absolutePath}")

        val cmd = listOf(
            "java",
            "-Dfile.encoding=UTF-8",
            "-Drascal.projectPath=${srcDir.absolutePath}",
            "-jar", rascalJar.absolutePath,
            "verilang::RunnerJson",   // ← VeriLang Rascal module
            filePath
        )

        val process = ProcessBuilder(cmd)
            .directory(srcDir)
            .redirectErrorStream(false)
            .start()
        process.outputStream.close()

        val stdoutFuture = java.util.concurrent.Executors.newSingleThreadExecutor()
            .submit<String> { process.inputStream.bufferedReader().readText() }
        val stderrFuture = java.util.concurrent.Executors.newSingleThreadExecutor()
            .submit<String> { process.errorStream.bufferedReader().readText() }

        val finished = process.waitFor(180, TimeUnit.SECONDS)
        if (!finished) {
            process.destroyForcibly()
            throw RuntimeException("Rascal timed out after 180s")
        }

        val stdout = stdoutFuture.get()
        val stderr = stderrFuture.get()

        println("--- STDERR (${stderr.length} chars) ---")
        if (stderr.isNotBlank()) println(stderr)
        println("--- exit code: ${process.exitValue()} ---")

        if (process.exitValue() != 0 && stdout.isBlank())
            throw RuntimeException("Rascal error (exit ${process.exitValue()}):\n$stderr")

        return stdout
    }

    /** Extract the first JSON object containing "success" from Rascal stdout. */
    private fun extractJson(output: String): String? {
        // Strip ANSI color codes
        val clean = output
            .replace(Regex("\\x1b\\[[^a-zA-Z]*[a-zA-Z]"), "")
            .replace(Regex("\\x1b[^\\[\\x1b]"), "")

        var start = 0
        while (start < clean.length) {
            val brace = clean.indexOf('{', start)
            if (brace == -1) break
            var depth = 0; var inStr = false; var esc = false; var end = -1
            for (i in brace until clean.length) {
                val c = clean[i]
                if (esc)               { esc = false; continue }
                if (c == '\\' && inStr) { esc = true;  continue }
                if (c == '"')          { inStr = !inStr; continue }
                if (!inStr) {
                    if (c == '{') depth++
                    else if (c == '}') { depth--; if (depth == 0) { end = i; break } }
                }
            }
            if (end != -1) {
                val candidate = clean.substring(brace, end + 1)
                try {
                    val parsed = Json.parseToJsonElement(candidate)
                    if (parsed is kotlinx.serialization.json.JsonObject && parsed.containsKey("success"))
                        return candidate
                } catch (_: Exception) {}
            }
            start = brace + 1
        }
        return null
    }
}
