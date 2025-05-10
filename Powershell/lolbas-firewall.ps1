$lolbasURL = "https://lolbas-project.github.io/api/lolbas.json"
$lolbasData = Invoke-RestMethod $lolbasURL

$pathsToBlock = @{}

foreach ($entry in $lolbasData.PSObject.Properties.Value){
    $name = $entry.Name
    if($entry.Full_Path){
        foreach ($path in $entry.Full_Path){
            if(Test-Path $path.Path -ErrorAction SilentlyContinue){
                if (-not $existingRule){
                    $pathsToBlock[$path] = $name
                }
            }
        }
    }
}

$jobs = @()
$maxConcurrentJobs = 25

foreach($kvp in $pathsToBlock.GetEnumerator()){
    while (@(Get-Job -State Running).Count -ge $maxConcurrentJobs){
        Start-Sleep 1
    }

    $path = $kvp.Key
    $name = $kvp.Value
    $displayName = "Block LOLBAS - $name"

    $jobs += Start-Job -ScriptBlock {
        param($displayName, $path)
        $exists = Get-NetFirewallRule -DisplayName $displayName -ErrorAction SilentlyContinue

        if(-not $exists){
            New-NetFirewallRule -DisplayName $displayName -Direction Outbound -Action Block -Program $path -Profile Any -Enabled True
            Write-Host "[+] Blocked $path"
        }else {
            Write-Host "[-] Already exists: $path"
        }
    } -ArgumentList $displayName, $path
}

Write-Host "[+] Waiting for all jhobs to run..."
$jobs | Wait-Job | Out-Null

$jobs | Receive-Job
$jobs | Remove-Job