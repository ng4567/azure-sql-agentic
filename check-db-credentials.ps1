[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [string]$SubscriptionId,

    [switch]$IncludeMaster
)

$ErrorActionPreference = 'Stop'

function Assert-CommandExists {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH. Install it and try again."
    }
}

function Invoke-AzJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    $out = & az @Args --only-show-errors -o json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Args -join ' ')"
    }

    if ([string]::IsNullOrWhiteSpace($out)) {
        return $null
    }

    return $out | ConvertFrom-Json
}

function Invoke-AzTsv {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    $out = & az @Args --only-show-errors -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Args -join ' ')"
    }

    return $out
}

function Write-EnvBlockSqlAuth {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlServer,

        [Parameter(Mandatory = $true)]
        [string]$Database,

        [string]$UsernameHint
    )

    $username = if ([string]::IsNullOrWhiteSpace($UsernameHint)) { '<sql_username>' } else { $UsernameHint }

    Write-Host "# Copy the lines below into your .env (SQL auth)"
    Write-Host "SQL_SERVER=$SqlServer"
    Write-Host "SQL_DATABASE=$Database"
    Write-Host "SQL_USERNAME=$username"
    Write-Host "SQL_PASSWORD=<sql_password>"
    Write-Host "# Optional convenience vars"
    Write-Host "SQL_DRIVER={ODBC Driver 18 for SQL Server}"
    Write-Host "SQL_CONNECTION_STRING=Driver={ODBC Driver 18 for SQL Server};Server=tcp:$SqlServer,1433;Database=$Database;Uid=$username;Pwd=<sql_password>;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    Write-Host "# If you don't know the password, you can reset it with: az sql server update -g $ResourceGroup -n <serverName> --admin-password <newPassword>"
}

function Write-EnvBlockAad {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlServer,

        [Parameter(Mandatory = $true)]
        [string]$Database
    )

    Write-Host "# Copy the lines below into your .env (Azure AD auth / Managed Identity compatible drivers)"
    Write-Host "SQL_SERVER=$SqlServer"
    Write-Host "SQL_DATABASE=$Database"
    Write-Host "# Optional: an ODBC connection string that uses your current Azure identity"
    Write-Host "SQL_CONNECTION_STRING=Driver={ODBC Driver 18 for SQL Server};Server=tcp:$SqlServer,1433;Database=$Database;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;Authentication=ActiveDirectoryDefault;"
}

Assert-CommandExists -Name 'az'

Write-Host "[check-db-credentials.ps1] Querying Azure SQL resources in resource group '$ResourceGroup'..."
Write-Host "[check-db-credentials.ps1] Note: Azure cannot retrieve existing SQL passwords. You'll need to supply the password manually in .env."
Write-Host ""

# Ensure we're logged in and optionally set subscription
try {
    $null = Invoke-AzTsv -Args @('account', 'show', '--query', 'id')
} catch {
    throw "Azure CLI is not authenticated. Run: az login"
}

if (-not [string]::IsNullOrWhiteSpace($SubscriptionId)) {
    & az account set --subscription $SubscriptionId --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription '$SubscriptionId'" }
}

$sqlServers = Invoke-AzJson -Args @('sql', 'server', 'list', '-g', $ResourceGroup)
$managedInstances = Invoke-AzJson -Args @('sql', 'mi', 'list', '-g', $ResourceGroup)

if ((-not $sqlServers -or $sqlServers.Count -eq 0) -and (-not $managedInstances -or $managedInstances.Count -eq 0)) {
    Write-Host "No Azure SQL logical servers or managed instances found in resource group '$ResourceGroup'."
    Write-Host "Tip: confirm the RG name or run: az resource list -g $ResourceGroup -o table"
    exit 0
}

if ($sqlServers -and $sqlServers.Count -gt 0) {
    Write-Host "=== Azure SQL logical servers (az sql server) ==="
    foreach ($s in $sqlServers) {
        $fqdn = $s.fullyQualifiedDomainName
        $admin = $s.administratorLogin
        Write-Host "- Server: $($s.name)"
        Write-Host "  FQDN:   $fqdn"
        if (-not [string]::IsNullOrWhiteSpace($admin)) { Write-Host "  Admin:  $admin" }

        $dbNames = @()
        try {
            $tsv = Invoke-AzTsv -Args @('sql', 'db', 'list', '-g', $ResourceGroup, '-s', $s.name, '--query', '[].name')
            $dbNames = $tsv -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            if (-not $IncludeMaster) {
                $dbNames = $dbNames | Where-Object { $_ -ne 'master' }
            }
        } catch {
            Write-Host "  Databases: <unable to list databases>"
        }

        if ($dbNames.Count -eq 0) {
            Write-Host "  Databases: <none found>"
        } else {
            Write-Host "  Databases: $($dbNames -join ', ')"

            foreach ($db in $dbNames) {
                Write-Host ""
                Write-Host "--- .env suggestion for $($s.name) / $db ---"
                Write-EnvBlockSqlAuth -SqlServer $fqdn -Database $db -UsernameHint $admin
                Write-Host ""
                Write-EnvBlockAad -SqlServer $fqdn -Database $db
            }
        }

        Write-Host ""
    }
}

if ($managedInstances -and $managedInstances.Count -gt 0) {
    Write-Host "=== Azure SQL Managed Instances (az sql mi) ==="
    foreach ($mi in $managedInstances) {
        $fqdn = $mi.fullyQualifiedDomainName
        if ([string]::IsNullOrWhiteSpace($fqdn)) {
            $fqdn = $mi.dnsName
        }

        $admin = $mi.administratorLogin

        Write-Host "- Managed Instance: $($mi.name)"
        Write-Host "  FQDN/DNS:         $fqdn"
        if (-not [string]::IsNullOrWhiteSpace($admin)) { Write-Host "  Admin:            $admin" }

        $dbNames = @()
        try {
            $tsv = Invoke-AzTsv -Args @('sql', 'midb', 'list', '-g', $ResourceGroup, '--mi', $mi.name, '--query', '[].name')
            $dbNames = $tsv -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        } catch {
            Write-Host "  Databases: <unable to list managed databases>"
        }

        if ($dbNames.Count -eq 0) {
            Write-Host "  Databases: <none found>"
        } else {
            Write-Host "  Databases: $($dbNames -join ', ')"

            foreach ($db in $dbNames) {
                Write-Host ""
                Write-Host "--- .env suggestion for MI $($mi.name) / $db ---"
                Write-EnvBlockSqlAuth -SqlServer $fqdn -Database $db -UsernameHint $admin
                Write-Host ""
                Write-EnvBlockAad -SqlServer $fqdn -Database $db
            }
        }

        Write-Host ""
    }
}

Write-Host "[check-db-credentials.ps1] Done. Pick ONE of the .env blocks above and paste it into your .env file."
