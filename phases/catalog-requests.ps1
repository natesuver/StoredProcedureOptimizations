
Param 
(
    [string] $traceDirectory,
    [string] $procedurename
) 
$nodeCount = 0
$requests = @()
Get-ChildItem $traceDirectory\* -Include *.bece, *.rml | 
Foreach-Object {
    $xml = ([xml](Get-Content -Path $_.FullName))
    $procedureNodes = $xml.SelectNodes("//CMD[contains(text(), '$procedurename')]")
    $nodeCount+=$procedureNodes.Count
    foreach ($procedureCommand in $procedureNodes) {
        $parentText = $procedureCommand.ParentNode.InnerText
        if ($requests -notcontains $parentText) {
            $requests+=$parentText;
        }
    }
   
}
$uniqueRequestCount = $requests.Count
write-host "Unique Requests: $uniqueRequestCount |  Total Requests: $nodeCount"

#. .\catalog-requests.ps1 -traceDirectory "C:\dev\thesis\StoredProcedureOptimizations\phases" -procedurename "usp_Schedules_GetByID"
