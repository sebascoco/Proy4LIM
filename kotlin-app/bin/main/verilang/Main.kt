package verilang

import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import verilang.ui.MainWindow

fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        title = "VeriLang — Runner",
        state = rememberWindowState(width = 900.dp, height = 700.dp)
    ) {
        MainWindow()
    }
}
