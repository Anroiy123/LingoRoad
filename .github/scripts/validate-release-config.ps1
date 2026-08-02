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
Assert-Contains $deployWorkflow 'ref: ${{ inputs.image_sha }}' "Deploy checkout must use the requested image SHA."
Assert-Contains $deployWorkflow '^[0-9a-f]{40}$' "Deploy input must require a full commit SHA."
Assert-Contains $deployWorkflow "git merge-base --is-ancestor" "Deploy SHA must belong to origin/main."
Assert-Contains $deployWorkflow "docker manifest inspect" "Deploy must verify immutable images exist."
Assert-Contains $deployWorkflow "chmod 0600" "Uploaded production environment must be mode 0600."

$deployScript = Get-Content "deploy/scripts/deploy.sh" -Raw
if ($deployScript -match '(?m)^\s*\.\s+"?\$env_file"?' -or $deployScript.Contains('source "$env_file"')) {
    throw "Deploy script must not source the production environment file."
}
Assert-Contains $deployScript "/api/ready" "Deploy must probe API readiness."
Assert-Contains $deployScript "--connect-timeout 3 --max-time 5" "Readiness probes need bounded curl timeouts."
Assert-Contains $deployWorkflow "sh /opt/lingoroad/deploy/scripts/deploy.sh" "Remote deploy must use the documented POSIX shell."

$androidWorkflow = Get-Content ".github/workflows/android-release.yml" -Raw
Assert-Contains $androidWorkflow 'VERSION_NAME: ${{ inputs.version_name }}' "Android inputs must enter shell through env."
Assert-Contains $androidWorkflow '^[1-9][0-9]*$' "Android version code must be a positive integer."
Assert-Contains $androidWorkflow 'new URL(process.env.PROD_API_BASE_URL)' "Android API URL needs structured validation."
if ($androidWorkflow -notmatch '(?ms)for name in KEYSTORE_BASE64 KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do\s+test -n "\$\{!name:-\}"') {
    throw "Android workflow must reject every empty signing secret before writing files."
}

$productionEnvironment = Get-Content "deploy/.env.production.example" -Raw
Assert-Contains $productionEnvironment "BootstrapAdmin__Email=" "Admin bootstrap email key does not match the backend contract."
Assert-Contains $productionEnvironment "BootstrapAdmin__Password=" "Admin bootstrap password key does not match the backend contract."

$prometheus = Get-Content "deploy/observability/prometheus.yml" -Raw
Assert-Contains $prometheus "http://ml:8001/ready" "Prometheus must probe ML readiness, not only liveness."
Assert-Contains $compose 'DATA_SOURCE_URI: db:5432/' "Postgres exporter URI must not embed credentials."
Assert-Contains $compose 'DATA_SOURCE_PASS: ${POSTGRES_PASSWORD:?' "Postgres exporter password must be separate and fail-fast."
Assert-Contains $compose 'Jwt__Secret: ${JWT_SECRET:?' "Critical Compose secrets must fail fast."

$backup = Get-Content "deploy/backup/backup.sh" -Raw
Assert-Contains $backup '/backups/daily' "Daily PostgreSQL backup is missing."
Assert-Contains $backup '/backups/weekly' "Weekly PostgreSQL backup is missing."
Assert-Contains $backup '(cd "$weekly" && sha256sum "$name"' "Weekly checksum must be regenerated relative to the weekly dump."
Assert-Contains $backup 'prune_backups "$daily" 7' "Backup retention must keep exactly seven daily dumps."
Assert-Contains $backup 'prune_backups "$weekly" 4' "Backup retention must keep exactly four weekly dumps."
if ($backup -match "(?i)speaking|audio|/tmp") {
    throw "Backup script must not include raw speaking audio or temporary files."
}

Write-Output "Release configuration validation passed."
