Param 
(
    [string] $servername = $(throw "You must supply a database server name "),
    [string] $databasename = $(throw "You must supply a database name"),
    [string] $stat_tracking_db = $(throw "You must supply a statistics database name to store candidate procedures"),
    [int] $polling_interval_ms = 500
) 

Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100
#CUSPVIMHMDBS01, SonetoMaster

$ple_template = @' 
use {1}
INSERT INTO {0}.dbo.ple_tracking
SELECT
[cntr_value],
getdate()
FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Manager%'
AND [counter_name] = 'Page life expectancy'
'@ -f $stat_tracking_db, $databasename

$stat_sql_template = @' 
INSERT INTO {0}.dbo.procedure_stats
SELECT 
s.name, 
o.name, 
MAX(proc_stats.cached_time),
1,
SUM(proc_stats.total_physical_reads),
SUM(proc_stats.total_worker_time),
SUM(proc_stats.total_elapsed_time),
SUM(proc_stats.execution_count),
MAX(proc_stats.last_execution_time)
FROM {1}.sys.dm_exec_procedure_stats as proc_stats
INNER JOIN {1}.sys.objects o ON 
    proc_stats.object_id = o.object_id 
INNER JOIN {1}.sys.schemas s ON 
    s.schema_id = o.schema_id
WHERE 
DB_NAME(proc_stats.database_ID) = '{1}' 
AND proc_stats.type = 'P'
AND NOT EXISTS (SELECT 1 FROM {0}.dbo.procedure_stats p WHERE 
                DB_NAME(proc_stats.database_ID) = '{1}' AND
                p.procedure_name = o.name AND
                p.cache_creation_date = proc_stats.cached_time
				)
GROUP BY s.name, o.name;

UPDATE S
SET
ran_on_peak = 1,
total_physical_reads= isnull(proc_stats.total_physical_reads,0),
total_worker_time= isnull(proc_stats.total_worker_time,0),
total_elapsed_time= isnull(proc_stats.total_elapsed_time,0),
execution_count= isnull(proc_stats.execution_count,0),
last_execution_date = proc_stats.last_execution_time
FROM 
{0}.dbo.procedure_stats S
INNER JOIN 
    (Select 
    o.name as procedure_name, 
    s.name as schema_name, 
    MAX(raw_stats.cached_time) as cached_time,
    MAX(raw_stats.last_execution_time) as last_execution_time,
    SUM(raw_stats.total_physical_reads) as total_physical_reads,
    SUM(raw_stats.total_worker_time) as total_worker_time,
    SUM(raw_stats.total_elapsed_time) as total_elapsed_time,
    SUM(raw_stats.execution_count) as execution_count
    FROM {1}.sys.dm_exec_procedure_stats as raw_stats
    INNER JOIN {1}.sys.objects o ON 
        raw_stats.object_id = o.object_id 
    INNER JOIN {1}.sys.schemas s ON 
        s.schema_id = o.schema_id
    WHERE 
    DB_NAME(raw_stats.database_ID) = '{1}' 
    AND raw_stats.type = 'P'
    GROUP BY o.name, s.name
    ) as proc_stats ON
        S.schema_name = proc_stats.schema_name AND
        S.procedure_name = proc_stats.procedure_name AND
        S.cache_creation_date = proc_stats.cached_time;
        
'@ -f $stat_tracking_db, $databasename


while(1)
{
    $time_start = Get-Date -format "HHmmssffff"
    Invoke-Sqlcmd -ServerInstance $servername -Database $stat_tracking_db -Query $ple_template
    Invoke-Sqlcmd -ServerInstance $servername -Database $stat_tracking_db -Query $stat_sql_template
    $time_end = Get-Date -format "HHmmssffff"
    $duration = [int64]$time_end - [int64]$time_start
    $now = Get-Date
    Write-Output "Invoked metric tracking for $servername -> $databasename -> duration: $duration ms -> at: $now, sleeping for $polling_interval_ms ms"
    start-sleep -milliseconds $polling_interval_ms
}

#. ./track-ple.ps1 -servername "DV-05-D-SQL01" -databasename "Performance" -stat_tracking_db "usage" -polling_interval_ms 500