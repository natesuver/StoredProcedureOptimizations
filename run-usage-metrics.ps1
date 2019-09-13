Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100
$pollingInterval = 5
while(1)
{
    $result = (Invoke-Sqlcmd -ServerInstance "DV-05-D-SQL01" -Database "SonetoDevelopment" -Query "Select top 1 name from sys.objects where name = 'CaptureReadMetrics'") | select -expand name
    if ($result -eq "CaptureReadMetrics")
    {
       Invoke-Sqlcmd -ServerInstance "DV-05-D-SQL01" -Database "SonetoDevelopment" -Query "EXEC CaptureReadMetrics 'SonetoDevelopment', $pollingInterval"
       Write-Output "Successfully Executed CaptureReadMetrics on $(Get-Date)"

    }
    else {
        Write-Output "Rebuilding CaptureReadMetrics on $(Get-Date)"
        $sp = [IO.File]::ReadAllText("c:\thesis\CaptureReadMetrics.sql")
        Invoke-Sqlcmd -ServerInstance "DV-05-D-SQL01" -Database "SonetoDevelopment" -Query $sp

    }
   
    $result = (Invoke-Sqlcmd -ServerInstance "DV-05-D-SQL01" -Database "SonetoDevelopment" -Query "Select top 1 name from sys.objects where name = 'CaptureWriteMetrics'") | select -expand name
    if ($result -eq "CaptureWriteMetrics")
    {
       Invoke-Sqlcmd -ServerInstance "DV-05-D-SQL01" -Database "SonetoDevelopment" -Query "EXEC CaptureWriteMetrics 'SonetoDevelopment', $pollingInterval"
       Write-Output "Successfully Executed CaptureWriteMetrics on $(Get-Date)"

    }
    else {
        Write-Output "Rebuilding CaptureWriteMetrics on $(Get-Date)"
        $sp = [IO.File]::ReadAllText("c:\thesis\CaptureWriteMetrics.sql")
        Invoke-Sqlcmd -ServerInstance "DV-05-D-SQL01" -Database "SonetoDevelopment" -Query $sp

    }

   

    start-sleep -seconds $pollingInterval
}

