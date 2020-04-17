Param 
( 
	#adapted from https://stackoverflow.com/questions/15072445/query-to-recursively-identify-object-dependencies
    [string] $servername = $(throw "You must supply a database server name to store candidate procedures"),
    [string] $databasename = $(throw "You must supply a database name"),
    [string] $procedure_name
) 

Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100

$dependent_sql = @' 
;WITH CTE_DependentObjects AS
(
	SELECT DISTINCT 
	b.object_id AS UsedByObjectId, 
	b.name AS UsedByObjectName, b.type AS UsedByObjectType, 
	c.object_id AS DependentObjectId, 
	c.name AS DependentObjectName , c.type AS DependenObjectType
	FROM  sys.sysdepends a
	INNER JOIN sys.objects b ON a.id = b.object_id
	INNER JOIN sys.objects c ON a.depid = c.object_id
	WHERE b.type IN ('P','V', 'FN') AND c.type IN ('U', 'P', 'V', 'FN') 
),
CTE_DependentObjects2 AS
(
   SELECT 
	  UsedByObjectId, UsedByObjectName, UsedByObjectType,
	  DependentObjectId, DependentObjectName, DependenObjectType, 
	  1 AS Level
   FROM CTE_DependentObjects a
   WHERE a.UsedByObjectName = '{0}'
   UNION ALL 
   SELECT 
	  a.UsedByObjectId, a.UsedByObjectName, a.UsedByObjectType,
	  a.DependentObjectId, a.DependentObjectName, a.DependenObjectType, 
	  (b.Level + 1) AS Level
   FROM CTE_DependentObjects a
   INNER JOIN  CTE_DependentObjects2 b 
	  ON a.UsedByObjectName = b.DependentObjectName
)

SELECT DependentObjectName,[Level] FROM CTE_DependentObjects2 
where DependenObjectType IN ('V','U')
AND [level] >=3
ORDER BY [Level], DependentObjectName    
'@ -f $procedure_name

 Invoke-Sqlcmd -ServerInstance $servername -Database $databasename -Query $dependent_sql -Verbose

 #. ./detect-nested-objects -servername "NSUVER-LW" -database "Soneto" -procedure_name "usp_Schedules_GetByID"
