plugins {
    id("idea")
}

val tfEnv : String by project
val tfBin = "terraform/terraform_0.13.5_linux_amd64"
val tfSrc = "src/main/terraform/"

fun sysEnv(name : String, defaultValue : String = "") : Pair<String, String> {
    val value = System.getenv(name) ?: defaultValue
    if(value == "")
        throw java.lang.IllegalArgumentException("Must supply an environment value for $name")
    return (name to value)
}
val tfExecEnv = hashMapOf(
    sysEnv("AWS_ACCESS_KEY_ID"),
    sysEnv("AWS_SECRET_ACCESS_KEY"),
    sysEnv("AWS_DEFAULT_REGION","us-east-2"),
    sysEnv("CLOUDFLARE_API_TOKEN")
)

fun tfExecWithVars(name : String, cmd : String, vararg args : Pair<String, String?>): Exec {
    val tfArgs = mutableListOf(
        "-var-file=config/default.tfvars",
        "-var-file=config/${tfEnv}.tfvars",
        "-var=environment_prefix=${tfEnv}")
    tfArgs.addAll(args.map { if(it.second == null) "-${it.first}" else "-${it.first}=${it.second}" })

    return task<Exec>(name) {
        environment(tfExecEnv)
        commandLine(tfBin, cmd, *tfArgs.toTypedArray(), tfSrc)
    }
}

tasks {
    tfExecWithVars("tfInit", "init", "backend-config" to "config/backend.tfvars")
    task<Exec>("tfWorkspaceNew") {
        environment(tfExecEnv)
        commandLine(tfBin, "workspace", "new", tfEnv, tfSrc)
        isIgnoreExitValue = true
        dependsOn("tfInit")
    }
    task<Exec>("tfWorkspaceSelect") {
        environment(tfExecEnv)
        commandLine(tfBin, "workspace", "select", tfEnv, tfSrc)
        dependsOn("tfWorkspaceNew")
    }
    tfExecWithVars("tfPlan", "plan").dependsOn("tfWorkspaceSelect")
    tfExecWithVars("tfApply", "apply", ("auto-approve" to null)).dependsOn("tfPlan")
}