$ErrorActionPreference = "Stop"

function Assert-Contains([string]$Text, [string]$Expected, [string]$Message) {
    if (-not $Text.Contains($Expected)) {
        throw $Message
    }
}

$compose = Get-Content "deploy/compose.production.yml" -Raw
foreach ($service in @("caddy", "admin", "api-migrate", "content-seed", "api", "ml", "db", "minio", "backup", "prometheus", "grafana", "loki")) {
    Assert-Contains $compose ("  " + $service + ":") "Missing production service: $service"
}
$mlBlock = [regex]::Match($compose, "(?ms)^  ml:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:|\z)").Groups["body"].Value
if ($mlBlock -match "(?m)^\s+ports:") {
    throw "ML must not publish a host port."
}
Assert-Contains $compose "condition: service_completed_successfully" "One-shot jobs must gate API startup."

$gradle = Get-Content "src/mobile/android/app/build.gradle.kts" -Raw
Assert-Contains $gradle 'applicationId = "com.lingoroad.app"' "Production application ID is incorrect."
foreach ($flavor in @("dev", "staging", "prod")) {
    Assert-Contains $gradle ('create("' + $flavor + '")') "Missing Android flavor: $flavor"
}
if ($gradle.Contains('signingConfigs.getByName("debug")')) {
    throw "Release signing must never fall back to the debug key."
}

$appConfig = Get-Content "src/mobile/lib/core/config/app_config.dart" -Raw
Assert-Contains $appConfig "Production API URL phải dùng HTTPS" "Production HTTPS fail-closed guard is missing."

$gitignore = Get-Content ".gitignore" -Raw
Assert-Contains $gitignore "src/mobile/android/key.properties" "Android key.properties is not ignored."
Assert-Contains $gitignore "*.jks" "Android keystores are not ignored."
Assert-Contains $gitignore "deploy/.env.production" "Production environment file is not ignored."

$deployWorkflow = Get-Content ".github/workflows/deploy-production.yml" -Raw
Assert-Contains $deployWorkflow "workflow_dispatch:" "Production deploy must be manual."
Assert-Contains $deployWorkflow "environment: production" "Production deploy must use a protected Environment."

$productionEnvironment = Get-Content "deploy/.env.production.example" -Raw
Assert-Contains $productionEnvironment "BootstrapAdmin__Email=" "Admin bootstrap email key does not match the backend contract."
Assert-Contains $productionEnvironment "BootstrapAdmin__Password=" "Admin bootstrap password key does not match the backend contract."

$prometheus = Get-Content "deploy/observability/prometheus.yml" -Raw
Assert-Contains $prometheus "http://ml:8001/ready" "Prometheus must probe ML readiness, not only liveness."

$backup = Get-Content "deploy/backup/backup.sh" -Raw
Assert-Contains $backup '/backups/daily' "Daily PostgreSQL backup is missing."
Assert-Contains $backup '/backups/weekly' "Weekly PostgreSQL backup is missing."
if ($backup -match "(?i)speaking|audio|/tmp") {
    throw "Backup script must not include raw speaking audio or temporary files."
}

Write-Output "Release configuration validation passed."
