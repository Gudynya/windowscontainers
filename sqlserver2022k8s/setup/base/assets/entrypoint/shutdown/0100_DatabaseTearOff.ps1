
Import-Module dbatools;
$sqlInstance = Connect-DbaInstance -SqlInstance localhost;
Write-Host "Connected to localhost database.";
$dbaDefaultPath = Get-DbaDefaultPath -SqlInstance $sqlInstance;
$dataPath = $dbaDefaultPath.Data;
Write-Host "Default data path: $dataPath";

switch ($Env:MSSQL_LIFECYCLE) {
    'ATTACH' {
        # Although this image is aimed at only being able to handle one database per MSSQL instance,
        # there is no harm in supporting attaching/dettaching multiple user databases in the ATTACH
        # lifecycle so it can be used in development environments or ad-hoc setups to handle
        # multiple databases.
        Write-Host "Dumping database state and detaching...";
        $jsonFilePath = Join-Path -Path $dataPath -ChildPath "structure.json";
        $allDatabases = Get-DbaDatabase -SqlInstance $sqlInstance | Where-Object { $_.IsSystemObject -eq $false }
        $databasesInfo = @();
        foreach ($database in $allDatabases) {
            Write-Host "Processing database $($database.Name)";
            $dataFiles = @()  # Initialize an empty array to hold file details
            # Iterate through each FileGroup and each file within that group
            foreach ($fileGroup in $database.FileGroups) {
                Write-Host "Processing file group $($fileGroup.Name)";
                foreach ($file in $fileGroup.Files) {
                    # Create a custom object with the LogicalName and PhysicalName for each file
                    Write-Host "Processing file $($file.Name) at path $($file.FileName)";
                    $fileInfo = New-Object PSObject -Property @{
                        "LogicalName"  = $file.Name  # Assuming 'Name' is the logical name of the file
                        "PhysicalName" = $file.FileName  # Assuming 'FileName' is the physical path of the file
                    }
                    $dataFiles += $fileInfo
                }
            }
            $dbInfo = @{
                "DatabaseName" = $database.Name
                "Files"        = $dataFiles
            }
            $databasesInfo += $dbInfo;
            Write-Host "Taking $($database.Name) offline....";
            Set-DbaDbState -SqlInstance $sqlInstance -Database $database.Name -Offline -Force -Confirm:$false;
            Write-Host "Dettaching $($database.Name)....";
            Dismount-DbaDatabase -SqlInstance $sqlInstance -Database $database.Name -Confirm:$false;
        }

        $output = @{
            "databases" = $databasesInfo
        }

        $output | ConvertTo-Json -Depth 99 | Out-File $jsonFilePath;
    }
    'PERSISTENT' {
        # Do nothing but stop the sql service, in persitent mode
        Stop-Service MSSQLSERVER;
    }
}