package verilang.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import verilang.model.RunResult
import verilang.service.LangService
import java.io.File
import javax.swing.JFileChooser
import javax.swing.filechooser.FileNameExtensionFilter

@Composable
fun MainWindow() {
    val service = remember { LangService() }
    val scope   = rememberCoroutineScope()

    var filePath by remember { mutableStateOf("") }
    var result   by remember { mutableStateOf<RunResult?>(null) }
    var running  by remember { mutableStateOf(false) }

    // Color palette (dark theme)
    val green   = Color(0xFF4CAF50)
    val red     = Color(0xFFEF5350)
    val yellow  = Color(0xFFFFA726)
    val blue    = Color(0xFF42A5F5)
    val bg      = Color(0xFF1A1A2E)
    val surface = Color(0xFF16213E)
    val card    = Color(0xFF0F3460)
    val text    = Color(0xFFE2E2E2)
    val accent  = Color(0xFF533483)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(bg)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // ── Header ──────────────────────────────────────────────────────────
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .background(accent, RoundedCornerShape(6.dp))
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Text("VL", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
            Column {
                Text("VeriLang Runner", color = text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text("ISIS-2111 PLE — Proyecto 4", color = Color(0xFF9E9E9E), fontSize = 12.sp)
            }
        }

        Divider(color = Color(0xFF333355))

        // ── File selector ───────────────────────────────────────────────────
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = filePath,
                onValueChange = { filePath = it },
                label = { Text("Ruta del archivo .vl", color = Color.Gray) },
                modifier = Modifier.weight(1f),
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = text, unfocusedTextColor = text,
                    focusedBorderColor = blue, unfocusedBorderColor = Color(0xFF555577)
                ),
                textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace, fontSize = 13.sp)
            )

            Button(
                onClick = {
                    val chooser = JFileChooser().apply {
                        fileFilter = FileNameExtensionFilter("Archivos VeriLang (*.vl)", "vl")
                        currentDirectory = File(System.getProperty("user.home"))
                    }
                    if (chooser.showOpenDialog(null) == JFileChooser.APPROVE_OPTION)
                        filePath = chooser.selectedFile.absolutePath
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF455A64))
            ) { Text("Buscar", color = text) }

            Button(
                onClick = {
                    scope.launch {
                        running = true
                        result  = null
                        result  = service.run(filePath.trim())
                        running = false
                    }
                },
                enabled = filePath.isNotBlank() && !running,
                colors = ButtonDefaults.buttonColors(containerColor = accent)
            ) {
                if (running)
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), color = text, strokeWidth = 2.dp)
                else
                    Text("Analizar", color = text)
            }
        }

        // ── Results panel ───────────────────────────────────────────────────
        result?.let { r ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {

                // Status bar
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    color = surface,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Estado del análisis", color = blue, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                            StatusChip("Parser",      r.parseOk,     green, red)
                            StatusChip("Type Check",  r.typeCheckOk, green, yellow)
                            StatusChip("Semántica",   r.semanticOk,  green, red)
                        }
                        if (r.module.isNotBlank()) {
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text("Módulo:", color = Color(0xFF9E9E9E), fontSize = 12.sp)
                                Text(r.module, color = blue, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }

                // Module summary (resumen from AST)
                if (r.resumen.isNotBlank()) {
                    InfoCard(
                        title = "Resumen del módulo",
                        content = r.resumen,
                        borderColor = blue,
                        bg = surface
                    )
                }

                // Modules list (extracted from output lines)
                val moduleLines = r.output.filter { it.startsWith("Module:") || it.startsWith("  uses:") }
                if (moduleLines.isNotEmpty()) {
                    InfoCard(
                        title = "Módulos",
                        content = moduleLines.joinToString("\n"),
                        borderColor = Color(0xFF7986CB),
                        bg = surface
                    )
                }

                // Spaces, operators, vars
                val structLines = r.output.filter {
                    it.startsWith("Space:") || it.startsWith("Operator:") || it.startsWith("Var:") ||
                    it.startsWith("Rule:") || it.startsWith("Expression:")
                }
                if (structLines.isNotEmpty()) {
                    InfoCard(
                        title = "Estructura del programa",
                        content = structLines.joinToString("\n"),
                        borderColor = green,
                        bg = surface
                    )
                }

                // General error
                if (r.error.isNotBlank()) {
                    InfoCard(title = "Error", content = r.error, borderColor = red, bg = Color(0xFF2D1515))
                }

                // Type errors
                if (r.typeErrors.isNotEmpty()) {
                    InfoCard(
                        title = "Errores de tipos (${r.typeErrors.size})",
                        content = r.typeErrors.joinToString("\n"),
                        borderColor = yellow,
                        bg = Color(0xFF2D2410)
                    )
                }

                // Semantic errors
                if (r.semanticErrors.isNotEmpty()) {
                    InfoCard(
                        title = "Errores semánticos (${r.semanticErrors.size})",
                        content = r.semanticErrors.joinToString("\n"),
                        borderColor = red,
                        bg = Color(0xFF2D1515)
                    )
                }

                // Full output (for non-categorized lines)
                val otherLines = r.output.filterNot { line ->
                    line.startsWith("Module:") || line.startsWith("  uses:") ||
                    line.startsWith("Space:") || line.startsWith("Operator:") ||
                    line.startsWith("Var:") || line.startsWith("Rule:") ||
                    line.startsWith("Expression:")
                }
                if (otherLines.isNotEmpty()) {
                    InfoCard(
                        title = "Salida adicional",
                        content = otherLines.joinToString("\n"),
                        borderColor = Color(0xFF9E9E9E),
                        bg = surface
                    )
                }

                // Pretty printer
                if (r.codigoFormateado.isNotBlank()) {
                    InfoCard(title = "Código formateado", content = r.codigoFormateado, borderColor = blue, bg = surface)
                }

                // Success banner
                if (r.success) {
                    Surface(color = Color(0xFF1B3A1B), shape = RoundedCornerShape(8.dp), modifier = Modifier.fillMaxWidth()) {
                        Row(modifier = Modifier.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Text("✓", color = green, fontSize = 18.sp)
                            Text("Análisis completado exitosamente", color = green, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }

        // Placeholder when nothing has run yet
        if (result == null && !running) {
            Box(modifier = Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
                Text(
                    "Selecciona un archivo .vl y presiona Analizar",
                    color = Color(0xFF555577),
                    fontSize = 14.sp
                )
            }
        }
    }
}

@Composable
private fun StatusChip(label: String, ok: Boolean, okColor: Color, failColor: Color) {
    val color = if (ok) okColor else failColor
    val icon  = if (ok) "✓" else "✗"
    Box(
        modifier = Modifier
            .background(color.copy(alpha = 0.18f), RoundedCornerShape(20.dp))
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        Text(
            "$icon $label: ${if (ok) "OK" else "FAIL"}",
            color = color,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun InfoCard(title: String, content: String, borderColor: Color, bg: Color) {
    Surface(color = bg, shape = RoundedCornerShape(8.dp), modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(1.dp)) {
            // Colored top border simulation via a thin box
            Box(modifier = Modifier.fillMaxWidth().height(3.dp).background(borderColor, RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp)))
            Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(title, color = borderColor, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 220.dp)
                        .verticalScroll(rememberScrollState())
                ) {
                    Text(
                        content,
                        color = Color(0xFFDDDDDD),
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        lineHeight = 18.sp
                    )
                }
            }
        }
    }
}
