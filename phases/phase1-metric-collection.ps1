Param 
(
    [string] $servername = $(throw "You must supply a database server name to store candidate procedures"),
    [string] $databasename = $(throw "You must supply a database name"),
    [string] $stat_tracking_db = $(throw "You must supply a statistics database name to store candidate procedures"),
    [int] $peak_hour_start,
    [int] $peak_hour_end,
    [int] $polling_interval = 30
) 

Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100
#CUSPVIMHMDBS01, SonetoMaster

$stat_sql_template = @' 
INSERT INTO {0}.dbo.procedure_stats
SELECT 
s.name, 
o.name, 
MAX(proc_stats.cached_time),
CASE WHEN DATEPART(HOUR, MAX(proc_stats.last_execution_time)) BETWEEN {2} AND {3} THEN 1 ELSE 0 END,
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
INNER JOIN {0}.dbo.candidates on
    candidates.schema_name = s.name AND
    candidates.procedure_name = o.name AND
    candidates.stage = 1
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
ran_on_peak = 
CASE WHEN ran_on_peak = 1 THEN 1
     WHEN DATEPART(HOUR, proc_stats.last_execution_time) BETWEEN {2} AND {3} THEN 1 
     ELSE 0 END,
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
    INNER JOIN {0}.dbo.candidates on
        candidates.schema_name = s.name AND
        candidates.procedure_name = o.name AND
        candidates.stage = 1
    WHERE 
    DB_NAME(raw_stats.database_ID) = '{1}' 
    AND raw_stats.type = 'P'
    GROUP BY o.name, s.name
    ) as proc_stats ON
        S.schema_name = proc_stats.schema_name AND
        S.procedure_name = proc_stats.procedure_name AND
        S.cache_creation_date = proc_stats.cached_time;
        
'@ -f $stat_tracking_db, $databasename, $peak_hour_start, $peak_hour_end

while(1)
{
    $time_start = Get-Date -format "HHmmssffff"
    Invoke-Sqlcmd -ServerInstance $servername -Database $stat_tracking_db -Query $stat_sql_template
    $time_end = Get-Date -format "HHmmssffff"
    $duration = [int]$time_end - [int]$time_start
    $now = Get-Date
    Write-Output "Invoked procedure metrics for $servername -> $databasename -> duration: $duration ms -> at: $now, sleeping for $polling_interval seconds"
    start-sleep -seconds $polling_interval
}

#. ./stage-2-metric-collection.ps1 -servername "NSUVER-LW" -databasename "Soneto" -stat_tracking_db "performance" -peak_hour_start 7 -peak_hour_end 18 -polling_interval 30
#. ./stage-2.ps1 -servername "CUSPVIMHMDBS01" -databasename "SeniorHelpers" -stat_tracking_db "SonetoMaster" -peak_hour_start 7 -peak_hour_end 18 -polling_interval 30