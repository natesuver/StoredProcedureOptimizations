
Param 
(
    [string] $planpath
) 
$xml = ([xml](Get-Content -Path $planpath))
$mgr=new-object System.Xml.XmlNamespaceManager($xml.Psbase.NameTable)
$mgr.AddNamespace("gr",$xml.ShowPlanXML.xmlns)
$xml.SelectNodes("//gr:RelOp[not(descendant::gr:RelOp)]",$mgr)  | sort { [decimal] $_.EstimatedTotalSubtreeCost }
