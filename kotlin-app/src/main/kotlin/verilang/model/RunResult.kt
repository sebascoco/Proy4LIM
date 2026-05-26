package verilang.model

import kotlinx.serialization.Serializable

/**
 * Represents the JSON result produced by verilang::RunnerJson in Rascal.
 * Field names must match exactly the JSON keys output by RunnerJson.rsc.
 */
@Serializable
data class RunResult(
    val success: Boolean = false,
    val module: String = "",
    val parseOk: Boolean = false,
    val typeCheckOk: Boolean = false,
    val semanticOk: Boolean = false,
    val typeErrors: List<String> = emptyList(),
    val semanticErrors: List<String> = emptyList(),
    val output: List<String> = emptyList(),
    val error: String = "",
    val codigoFormateado: String = "",
    val resumen: String = ""
)
