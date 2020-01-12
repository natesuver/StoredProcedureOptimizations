Param 
(
	[string] $servername = $(throw "You must supply a database server name"),
	[string] $databasename = $(throw "You must supply a database name"),
    [string] $stat_tracking_db = $(throw "You must supply a statistics database name")
) 

Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100

$template = @' 
DECLARE @cpu_weight DECIMAL=1, @physical_read_weight DECIMAL=1, @wait_time_weight DECIMAL=1
DECLARE @Raw TABLE (schema_name NVARCHAR(20), procedure_name NVARCHAR(500), total_physical_reads DECIMAL(18,0), total_worker_time DECIMAL(18,0), total_elapsed_time DECIMAL(18,0), execution_count DECIMAL(18,0), mean_normal_c DECIMAL(10,6), mean_normal_p DECIMAL(10,6), mean_normal_w DECIMAL(10,6), objective_value DECIMAL(10,6))
;with agg_cte (schema_name, procedure_name, total_physical_reads, total_worker_time, total_elapsed_time, execution_count, total_minutes)
AS
(
	select 
	schema_name,
	procedure_name,
	CONVERT(DECIMAL,SUM(ISNULL(total_physical_reads,0))),
	CONVERT(DECIMAL,SUM(ISNULL(total_worker_time,0))),
	CONVERT(DECIMAL,SUM(ISNULL(total_elapsed_time,0))),
	CONVERT(DECIMAL,SUM(ISNULL(execution_count,0))),
	CONVERT(DECIMAL,SUM(DATEDIFF(minute,cache_creation_date,last_execution_date)))
	FROM {0}.dbo.procedure_stats stats
    WHERE

    CONVERT(decimal,execution_count) > 0 and 
    CONVERT(decimal,total_physical_reads) > 0 AND
    CONVERT(decimal,total_worker_time) > 0 AND
    CONVERT(decimal,total_elapsed_time) > 0 AND
    DATEDIFF(minute,cache_creation_date,last_execution_date) > 0 AND
    exists (Select 1 from {0}.dbo.procedure_stats s where s.schema_name = stats.schema_name and s.procedure_name = stats.procedure_name and stats.ran_on_peak = 1)	
	GROUP BY schema_name, procedure_name
), avg_cte  (schema_name, procedure_name, total_physical_reads, total_worker_time, total_elapsed_time, execution_count)
AS (
	SELECT
    schema_name, 
	procedure_name,
	AVG(total_physical_reads / execution_count) OVER(PARTITION BY schema_name, procedure_name ),
	AVG(total_worker_time / execution_count) OVER(PARTITION BY  schema_name, procedure_name ),
	AVG(total_elapsed_time / execution_count) OVER(PARTITION BY  schema_name, procedure_name ),
	AVG(execution_count / total_minutes) OVER(PARTITION BY  schema_name, procedure_name )
	FROM agg_cte
)

INSERT INTO @Raw
Select schema_name,procedure_name, ROUND(total_physical_reads,2), ROUND(total_worker_time,2), ROUND(total_elapsed_time,2), ROUND(execution_count,2),0,0,0,0  
 from avg_cte

   
DECLARE @min_cpu DECIMAL, @max_cpu DECIMAL, @min_physical_reads DECIMAL, @max_physical_reads DECIMAL, @min_wait_time DECIMAL, @max_wait_time DECIMAL
SELECT
@min_cpu = MIN(total_worker_time),
@max_cpu = MAX(total_worker_time),
@min_physical_reads = MIN(total_physical_reads),
@max_physical_reads = MAX(total_physical_reads),
@min_wait_time = MIN(total_elapsed_time*execution_count),
@max_wait_time = MAX(total_elapsed_time*execution_count)
FROM @Raw


UPDATE @Raw SET 
mean_normal_c = @cpu_weight*((total_worker_time-@min_cpu)/(@max_cpu-@min_cpu)),
mean_normal_p = @physical_read_weight*((total_physical_reads-@min_physical_reads)/(@max_physical_reads-@min_physical_reads)),
mean_normal_w = @wait_time_weight*(((total_elapsed_time*execution_count)-@min_wait_time)/(@max_wait_time-@min_wait_time))
UPDATE @Raw SET objective_value = mean_normal_c+mean_normal_p+mean_normal_w

DELETE from {0}.dbo.candidates where stage = 2
INSERT INTO {0}.dbo.candidates (schema_name, procedure_name,stage, objective_weight)
SELECT TOP 10 PERCENT schema_name, procedure_name,2, objective_value FROM @Raw ORDER BY objective_value desc

INSERT INTO {0}.dbo.dependent_tables
SELECT DISTINCT s.name, procs.name, tabs.name,0
FROM {1}.sys.sql_dependencies depends 
INNER JOIN {1}.sys.procedures procs ON 
	procs.object_id = depends.object_id
INNER JOIN {1}.sys.tables     tabs ON 
	tabs.object_id = depends.referenced_major_id
INNER JOIN {1}.sys.schemas s ON
	s.schema_id = procs.schema_id
INNER JOIN {0}.dbo.candidates on 
	candidates.schema_name = s.name AND
	candidates.procedure_name = procs.name AND
	candidates.stage = 2
        
'@ -f $stat_tracking_db, $databasename

$time_start = Get-Date -format "HHmmssffff"
Invoke-Sqlcmd -ServerInstance $servername -Database $stat_tracking_db -Query $template
$time_end = Get-Date -format "HHmmssffff"
$duration = [int]$time_end - [int]$time_start
$now = Get-Date
Write-Output "Captured Objective Function Metrics for $servername -> $stat_tracking_db -> duration: $duration ms -> at: $now"


#. ./stage-2-compute-objective-function.ps1 -servername "CUSPVIMHMDBS01" -stat_tracking_db "SonetoMaster"