Param 
(
    [string] $folderpath = $(throw "You must supply a path to the stored procedure source code"),
    [string] $outputfile = $(throw "You must supply a file path to the output (path is not required)")
) 
Remove-Item -path $outputfile
New-Item -Path . -Name $outputfile -ItemType "file"
$files = Get-ChildItem $folderpath
$validCandidates = @()
foreach ($file in $files) {
    $content = Get-Content $file.FullName
    $hasDMLMatch = $content -match '(UPDATE|INSERT INTO|DELETE|MERGE)(\r\n|\r|\n|\s)+([A-Za-z]|\[)'
    $hasExcludedProcedureMatch = $file.Name -match '(usp_rpt)' #|usp_Sync_T #this particular filter is specific to this implementation, excluding, by filename, procedures used by the microsoft sync framework and reporting services.  Adjust as necessary.
    if ($hasDMLMatch.Length -eq 0 -And $hasExcludedProcedureMatch -eq $false) {
        $validCandidates += $file.Basename
    }
}
foreach ($candidate in $validCandidates) {
    Add-Content -Path .\$outputfile -Value $candidate
}
Write-Output "Processing for get-non-dml-procedures is complete!"

#.\get-non-dml-procedures.ps1 -folderpath "C:\dev\main\Database\Sql\Stored Procedures" -outputfile "stage-1-out.txt"