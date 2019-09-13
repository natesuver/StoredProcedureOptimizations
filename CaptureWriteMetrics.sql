--Uses the sql server dm_db_index_usage_stats system view to accumulate "write" statistics about a given set of tables (Specified in tracked_tables) for a given time interval.
--This procedure is meant to be executed by a caller once every @PollingTimeinSeconds in order to accumulate data over time
--This gives us a nice overall assessment of how tables are written to in a period of time (note that this is only useful for a rough assessment)
--https://littlekendra.com/2016/06/30/index-usage-stats-insanity-sys-dm_db_index_usage_stats-dear-sql-dba/
--Contains a decent discussion on the peculiarities with this technique
--Make sure to run the UsageDatabase.sql script before creating this procedure on your target database
CREATE PROCEDURE [dbo].[CaptureWriteMetrics]
@DatabaseName NVARCHAR(50),
@PollingTimeinSeconds INT

AS

DECLARE @databaseId INT
SELECT @databaseId = DB_ID(@DatabaseName)
DECLARE @CurrentWriteTime DATETIME = DATEADD(SECOND,@PollingTimeinSeconds *-1,GETDATE())
-- For each table, find the last Write date that is greater than right now -n seconds.
-- If we find a hit, get the total Write count, and then get the total Write count for the prior writes for that same table which is the max(date) less than the last write date.
-- subtract the second number from the first number, and store that as the delta number for that run for that table.

DECLARE @LastWrites TABLE (LastWriteDate DATETIME, TableName NVARCHAR(50), TotalWriteCount INT)
DECLARE @PriorWrites TABLE (LastWriteDate DATETIME, TableName NVARCHAR(50), TotalWriteCount INT)

--search for all table Writes that have occurred in the last n seconds.
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
FROM SonetoDevelopment.sys.dm_db_index_usage_stats AS s
INNER JOIN SonetoDevelopment.sys.indexes AS i
ON s.object_id = i.object_id
AND i.index_id = s.index_id
INNER JOIN usage.dbo.tracked_tables tt ON 
	tt.TableName = object_name(s.object_id)
WHERE objectproperty(s.object_id,'IsUserTable') = 1
AND s.database_id = @databaseId
AND s.last_user_update >= @CurrentWriteTime
GROUP BY object_name(s.object_id)

;WITH LastWrite (TableName, WriteTime)
AS
( --grab a list of tables that have the highest last action time right before the current Write time.
	SELECT 
	u.TableName, 
	MAX(u.LastActionTime)
	FROM
	usage.dbo.usage_stats u
	WHERE
	u.ActionType =1 --Write flag
	AND u.LastActionTime < @CurrentWriteTime
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
INNER JOIN usage.dbo.usage_stats usage ON
	usage.TableName = lr.TableName AND
	usage.LastActionTime = lr.WriteTime;

INSERT INTO usage.dbo.usage_stats
(
	TableName,
	ActionType,
	LastActionTime,
	TotalRowsAffected,
	DeltaRowsAffected
)
SELECT DISTINCT
lr.TableName,
1, --Write Flag
lr.LastWriteDate,
lr.TotalWriteCount,
CASE WHEN ISNULL(pr.TotalWriteCount,0) < lr.TotalWriteCount THEN lr.TotalWriteCount - ISNULL(pr.TotalWriteCount,0) ELSE 0 END
FROM @LastWrites lr
LEFT OUTER JOIN @PriorWrites pr ON
	pr.TableName = lr.TableName
WHERE
CASE WHEN ISNULL(pr.TotalWriteCount,0) < lr.TotalWriteCount THEN lr.TotalWriteCount - ISNULL(pr.TotalWriteCount,0) ELSE 0 END > 0