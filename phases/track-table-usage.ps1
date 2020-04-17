
Param 
(
    [string] $servername = $(throw "You must supply a database server name to store candidate procedures"),
    [string] $databasename = $(throw "You must supply a database name to store candidate procedures"),
    [string] $stat_tracking_db = $(throw "You must supply a statistics database name"),
    [int] $polling_interval = $(throw "You must supply a polling interval (in seconds)")
) 
Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100
$sql_template =  @'
use {1}
DECLARE @databaseId INT
SELECT @databaseId = DB_ID('{1}')
DECLARE @CurrentWriteTime DATETIME = DATEADD(SECOND,(-{2}),GETDATE())
-- For each table, find the last Write date that is greater than right now -{2} seconds.
-- If we find a hit, get the total Write count, and then get the total Write count for the prior Writing for that same table which is the max(date) less than the read date.
-- subtract the second number from the first number, and store that as the delta number for that run for that table.

DECLARE @LastWrites TABLE (LastWriteDate DATETIME, TableName NVARCHAR(50), TotalWriteCount INT)
DECLARE @PriorWrites TABLE (LastWriteDate DATETIME, TableName NVARCHAR(50), TotalWriteCount INT)

--search for all table Writes that have occurred in the last {2} seconds.
INSERT INTO @LastWrites
(
    LastWriteDate,
    TableName,
    TotalWriteCount
)
SELECT 
MAX(s.last_user_update),
object_name(s.object_id),
SUM(ISNULL(user_updates,0))
FROM {1}.sys.dm_db_index_usage_stats AS s
INNER JOIN {1}.sys.indexes AS i ON 
    s.object_id = i.object_id AND
    i.index_id = s.index_id
INNER JOIN (Select DISTINCT table_name from {0}.dbo.dependent_tables) AS dt ON 
	dt.table_name = object_name(s.object_id)
WHERE 
s.database_id = @databaseId
AND ISNULL(user_updates,0) > 0
AND s.last_user_seek >= @CurrentWriteTime
GROUP BY object_name(s.object_id)

;WITH LastWrite (TableName, WriteTime)
AS
( --grab a list of tables that have the highest last action time right before the current Write time.
	SELECT 
	u.TableName, 
	MAX(u.LastActionTime)
	FROM
	{0}.dbo.table_usage_stats u
	WHERE
	u.LastActionTime < @CurrentWriteTime
	GROUP BY u.TableName
)
INSERT INTO @PriorWrites
(
    LastWriteDate,
    TableName,
    TotalWriteCount
)
SELECT
lr.WriteTime,
lr.TableName,
usage.TotalRowsAffected
FROM LastWrite lr
INNER JOIN {0}.dbo.table_usage_stats usage ON
	usage.TableName = lr.TableName AND
	usage.LastActionTime = lr.WriteTime;

INSERT INTO {0}.dbo.table_usage_stats
(
    TableName,
    LastActionTime,
    TotalRowsAffected,
    DeltaRowsAffected
)
SELECT DISTINCT
lr.TableName,
lr.LastWriteDate,
lr.TotalWriteCount,
CASE WHEN ISNULL(pr.TotalWriteCount,0) < lr.TotalWriteCount THEN lr.TotalWriteCount - ISNULL(pr.TotalWriteCount,0) ELSE 0 end
FROM @LastWrites lr
LEFT OUTER JOIN @PriorWrites pr ON
    pr.TableName = lr.TableName
WHERE lr.TotalWriteCount - ISNULL(pr.TotalWriteCount,0) > 0
'@ -f $stat_tracking_db, $databasename, $polling_interval

while(1)
{
    $time_start = Get-Date -format "HHmmssffff"
    Invoke-Sqlcmd -ServerInstance $servername -Database $stat_tracking_db -Query $sql_template 
    $time_end = Get-Date -format "HHmmssffff"
    $duration = [int]$time_end - [int]$time_start
    $now = Get-Date
    Write-Output "Invoked table usage metrics for $servername -> $databasename -> duration: $duration ms -> at: $now, sleeping for $polling_interval seconds"
    start-sleep -seconds $polling_interval
}

Write-Output "Processing track-table-usage is complete!"
