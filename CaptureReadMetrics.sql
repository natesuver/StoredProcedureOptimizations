--Uses the sql server dm_db_index_usage_stats system view to accumulate "read" statistics about a given set of tables (Specified in tracked_tables) for a given time interval.
--This procedure is meant to be executed by a caller once every @PollingTimeinSeconds in order to accumulate data over time
--This gives us a nice overall assessment of how tables are read fron in a period of time (note that this is only useful for a rough assessment)
--https://littlekendra.com/2016/06/30/index-usage-stats-insanity-sys-dm_db_index_usage_stats-dear-sql-dba/
--Contains a decent discussion on the peculiarities with this technique
--Make sure to run the UsageDatabase.sql script before creating this procedure on your target database
CREATE PROCEDURE [dbo].[CaptureReadMetrics]
@DatabaseName NVARCHAR(50),
@PollingTimeinSeconds INT

AS

DECLARE @databaseId INT
SELECT @databaseId = DB_ID(@DatabaseName)
DECLARE @CurrentReadTime DATETIME = DATEADD(SECOND,@PollingTimeinSeconds *-1,GETDATE())
-- For each table, find the last read date that is greater than right now -10 seconds.
-- If we find a hit, get the total read count, and then get the total read count for the prior reading for that same table which is the max(date) less than the read date.
-- subtract the second number from the first number, and store that as the delta number for that run for that table.

DECLARE @LastReads TABLE (LastReadDate DATETIME, TableName NVARCHAR(50), TotalReadCount INT)
DECLARE @PriorReads TABLE (LastReadDate DATETIME, TableName NVARCHAR(50), TotalReadCount INT)

--search for all table reads that have occurred in the last n seconds.
INSERT INTO @LastReads
(
    LastReadDate,
    TableName,
    TotalReadCount
)
SELECT 
MAX(s.last_user_seek),
object_name(s.object_id),
SUM(ISNULL(user_seeks,0) + ISNULL(user_scans,0) + ISNULL(user_lookups,0))
FROM SonetoDevelopment.sys.dm_db_index_usage_stats AS s
INNER JOIN SonetoDevelopment.sys.indexes AS i
ON s.object_id = i.object_id
AND i.index_id = s.index_id
INNER JOIN usage.dbo.tracked_tables tt ON 
	tt.TableName = object_name(s.object_id)
WHERE objectproperty(s.object_id,'IsUserTable') = 1
AND s.database_id = @databaseId
AND s.last_user_seek >= @CurrentReadTime
GROUP BY object_name(s.object_id)

;WITH LastRead (TableName, ReadTime)
AS
( --grab a list of tables that have the highest last action time right before the current read time.
	SELECT 
	u.TableName, 
	MAX(u.LastActionTime)
	FROM
	usage.dbo.usage_stats u
	WHERE
	u.ActionType =0 --reads
	AND u.LastActionTime < @CurrentReadTime
	GROUP BY u.TableName
)
INSERT INTO @PriorReads
(
    LastReadDate,
    TableName,
    TotalReadCount
)
SELECT
lr.ReadTime,
lr.TableName,
usage.TotalRowsAffected
FROM LastRead lr
INNER JOIN usage.dbo.usage_stats usage ON
	usage.TableName = lr.TableName AND
	usage.LastActionTime = lr.ReadTime;

INSERT INTO usage.dbo.usage_stats
(
    TableName,
    ActionType,
    LastActionTime,
    TotalRowsAffected,
    DeltaRowsAffected
) --the below case statement removes a subtle oddity of the sys.dm_db_index_usage_stats view
SELECT DISTINCT
lr.TableName,
0, --read
lr.LastReadDate,
lr.TotalReadCount,
CASE WHEN ISNULL(pr.TotalReadCount,0) < lr.TotalReadCount THEN lr.TotalReadCount - ISNULL(pr.TotalReadCount,0) ELSE 0 end
FROM @LastReads lr
LEFT OUTER JOIN @PriorReads pr ON
	pr.TableName = lr.TableName
WHERE
CASE WHEN ISNULL(pr.TotalReadCount,0) < lr.TotalReadCount THEN lr.TotalReadCount - ISNULL(pr.TotalReadCount,0) ELSE 0 END > 0


