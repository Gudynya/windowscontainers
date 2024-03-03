#################################################
# This script applies basic server settings 
# and starts the server
#################################################

$global:ErrorActionPreference = if ($null -ne $Env:SBS_ENTRYPOINTERRORACTION ) { $Env:SBS_ENTRYPOINTERRORACTION } else { 'Stop' }

# Check if the event source exists, if not, create it
if (-not [System.Diagnostics.EventLog]::SourceExists('MSSQL_MANAGEMENT')) {
    [System.Diagnostics.EventLog]::CreateEventSource('MSSQL_MANAGEMENT', 'Application');
}

$needsRestart = $false;

Start-Service 'MSSQLSERVER';
$sqlInstance = Connect-DbaInstance -SqlInstance localhost;

# Define default settings
$defaultSettings = @{
    "max degree of parallelism"  = 2
    "backup compression default" = 1
}

# Read the environment variable
$envSettings = $Env:MSSQL_SPCONFIGURE;

# Parse the environment variable settings
$parsedEnvSettings = @{}
if ($null -ne $envSettings) {
    $settingsArray = $envSettings.Split(';')
    foreach ($setting in $settingsArray) {
        $splitSetting = $setting.Split(':');
        $parsedEnvSettings[$splitSetting[0].Trim()] = $splitSetting[1].Trim();
    }
}

$finalSettings = $defaultSettings.Clone();
foreach ($key in $parsedEnvSettings.Keys) {
    $finalSettings[$key] = $parsedEnvSettings[$key];
}

# Apply the settings
foreach ($key in $finalSettings.Keys) {
    $currentConfig = Get-DbaSpConfigure -SqlInstance $sqlInstance -Name $key;
    $isDynamic = $currentConfig.IsDynamic; # If dynamic, the server does NOT need a restart after the change.
    $currentValue = $currentConfig.ConfiguredValue;
    $newValue = $finalSettings[$key];
    if ($newValue -ne $currentValue) {
        Set-DbaSpConfigure -SqlInstance $sqlInstance -Name $key -Value $newValue;
        Write-Host "SPCONFIGURE SET '$key' to '$newValue' from '$currentValue' with isDymamic '$isDynamic'";
        if ($true -eq $isDynamic) {
            $needsRestart = $true;
        }
    }
}

if (($true -eq $needsRestart) -or ($Env:MSSQL_SPCONFIGURERESTART -eq '1')) {
    Write-Host "Server post config restart.";
    Restart-DbaService -ComputerName "localhost";
}