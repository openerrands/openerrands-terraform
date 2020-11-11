plugins {
    id("idea")
}

val tfEnv : String by project
val tfBin = "terraform/terraform_0.13.5_linux_amd64"
val tfSrc = "src/main/terraform/"

fun sysEnv(name : String, defaultValue : String? = null) : String {
    return System.getenv(name) ?: defaultValue ?:
        throw java.lang.IllegalArgumentException("Must supply an environment value for $name")
}
val tfExecEnv = hashMapOf(
    "AWS_ACCESS_KEY_ID" to sysEnv("AWS_ACCESS_KEY_ID"),
    "AWS_SECRET_ACCESS_KEY" to sysEnv("AWS_SECRET_ACCESS_KEY"),
    "AWS_DEFAULT_REGION" to sysEnv("AWS_DEFAULT_REGION", "us-east-2"),
    "CLOUDFLARE_API_TOKEN" to sysEnv("CLOUDFLARE_API_TOKEN"),
    "TF_VAR_auth_amazon_client_id" to sysEnv("AUTH_AMAZON_CLIENT_ID"),
    "TF_VAR_auth_amazon_client_secret" to sysEnv("AUTH_AMAZON_CLIENT_SECRET")
)

fun formatArgs(args : Array<out Pair<String, String?>>) : Array<String> {
    return args.map {
        when (it.second) {
            "" -> it.first
            null -> "-${it.first}"
            else -> "-${it.first}=${it.second}"
        }
    }.toTypedArray()
}
fun tfExec(name : String, cmd : String, vararg args : Pair<String, String?>) : Exec {
    return task<Exec>(name) {
        environment(tfExecEnv)
        commandLine(tfBin, cmd, *formatArgs(args), tfSrc)
    }
}
fun tfExecWithVars(name : String, cmd : String, vararg args : Pair<String, String?>): Exec {
    return tfExec(name, cmd,
        *args,
        "var-file" to "config/default.tfvars",
        "var-file" to "config/${tfEnv}.tfvars",
        "var" to "environment_prefix=${tfEnv}"
    )
}

tasks {
    tfExec("tfInit", "init", "backend-config" to "config/backend.tfvars")
    tfExec("tfWorkspaceNew", "workspace", "new" to "", tfEnv to "").setIgnoreExitValue(true).dependsOn("tfInit")
    tfExec("tfWorkspaceSelect", "workspace", "select" to "", tfEnv to "").dependsOn("tfWorkspaceNew")
    tfExecWithVars("tfPlan", "plan").dependsOn("tfWorkspaceSelect")
    tfExecWithVars("tfApply", "apply", ("auto-approve" to null)).dependsOn("tfPlan")
}