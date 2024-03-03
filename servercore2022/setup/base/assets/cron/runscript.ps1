﻿param(
	[Parameter(Mandatory = $true)]
	[string]$path
)

function Write-ErrorLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$baseName,

		[Parameter(Mandatory = $true)]
		[System.Exception]$exception
	)

	$eventId = 23003
	$entryType = [System.Diagnostics.EventLogEntryType]::Error

	if ($exception -is [System.AggregateException]) {
		$exception.Flatten().InnerExceptions | ForEach-Object {
			$message = "Error running cron " + $baseName + ": " + $_.Message
			Write-EventLog -LogName "Application" -Source "ContainerLifecycle" -EventID $eventId -EntryType $entryType -Message $message
		}
	}
 else {
		$message = "Error running cron " + $baseName + ": " + $exception.Message
		Write-EventLog -LogName "Application" -Source "ContainerLifecycle" -EventID $eventId -EntryType $entryType -Message $message
	}
}

Get-ChildItem $path -Filter *.ps1 | 
Foreach-Object {
	$Error.Clear();
	$baseName = $_.BaseName;
	$fullName = $_.FullName;
	Try {
		$message = "PING Cron started: " + $baseName;
		Write-EventLog -LogName "Application" -Source "ContainerLifecycle" -EventID 23000 -EntryType Information -Message $message;
		& $fullName
		if ($LASTEXITCODE -ne 0) {
			if ($Error.Count -gt 0) {
				for ($x = 0; $x -lt $Error.Count; $x = $x + 1) {
					Write-ErrorLog -baseName $baseName -exception $Error[$x].Exception
				}
			}
			else {
				$customException = New-Object System.Exception "An error ocurred with LASTEXITCODE=$($LASTEXITCODE), but the details could not be obtained."
				Write-ErrorLog -baseName $baseName -exception $customException
			}
		}
	}
	Catch {
		Write-ErrorLog -baseName $baseName -exception $_.Exception
	}
}