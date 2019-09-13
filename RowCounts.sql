--Note: Assumes that a seperate "usage" database exists on your server which contains the tracked_tables table.
SELECT SCHEMA_NAME(schema_id) AS TableName,
       tabs.name AS TableName,
       SUM(parts.rows) AS TotalRows
FROM sys.tables AS tabs
    JOIN sys.partitions AS parts
        ON tabs.object_id = parts.object_id
           AND parts.index_id IN ( 0, 1 )
    INNER JOIN usage.dbo.tracked_tables tt
        ON tt.TableName = tabs.name
GROUP BY SCHEMA_NAME(schema_id),
         tabs.name
ORDER BY TotalRows;
