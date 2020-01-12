#
# Given a database server name, database name, input file with a list of candidate procedures and the stage of the filtering, load the procedure names and stage into the "candidates" table in the target database.
#

Param 
(
    [string] $servername = $(throw "You must supply a database server name to store candidate procedures"),
    [string] $databasename = $(throw "You must supply a database name to store candidate procedures"),
    [string] $inputfile = $(throw "You must supply an input file that contains a list of candidates"),
    [int] $stage = $(throw "You must supply the stage number")
) 
Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100
$create_table =  @'
IF NOT EXISTS (Select * from sys.objects where name='candidates') 
BEGIN 
    CREATE TABLE [dbo].[candidates](
        [schema_name] [nvarchar](30) NOT NULL,
        [procedure_name] [nvarchar](250) NOT NULL,
        [objective_weight] INT NULL,
        [stage] [int] NOT NULL,
    CONSTRAINT [PK_candidates] PRIMARY KEY CLUSTERED 
    (
        [schema_name] ASC,
        [procedure_name] ASC,
        [stage] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
    ) ON [PRIMARY]  
END
IF NOT EXISTS (Select * from sys.objects where name='procedure_stats') 
BEGIN 
    CREATE TABLE [dbo].[procedure_stats](
        [schema_name] [nvarchar](30) NOT NULL,
        [procedure_name] [nvarchar](250) NOT NULL,
		[cache_creation_date] datetime NOT NULL,
        [ran_on_peak] [bit] NOT NULL,
		[total_physical_reads] DECIMAL NULL,
		[total_worker_time]  DECIMAL NULL,
		[total_elapsed_time]   DECIMAL NULL,
        [execution_count] DECIMAL NULL,
        [last_execution_date] datetime NOT NULL
    CONSTRAINT [PK_procedure_stats] PRIMARY KEY CLUSTERED 
    (
        [schema_name] ASC,
        [procedure_name] ASC,
        [cache_creation_date] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
    ) ON [PRIMARY]  
END
IF NOT EXISTS (Select * from sys.objects where name='dependent_tables') 
BEGIN 
    CREATE TABLE [dbo].[dependent_tables](
        [schema_name] [NVARCHAR](30) NOT NULL,
        [procedure_name] [NVARCHAR](250) NOT NULL,
        [table_name] [NVARCHAR](100) NOT NULL,
        [total_writes] [INT] NULL
    CONSTRAINT [PK_dependent_tables] PRIMARY KEY CLUSTERED 
    (
        [schema_name] ASC,
        [procedure_name] ASC,
        [table_name] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
    ) ON [PRIMARY]
END
IF NOT EXISTS (Select * from sys.objects where name='table_usage_stats') 
BEGIN 
    CREATE TABLE [dbo].[table_usage_stats](
        [Id] [bigint] IDENTITY(1,1) NOT NULL,
        [TableName] [nvarchar](50) NOT NULL,
        [ProcessTime] [datetime] NULL,
        [LastActionTime] [datetime] NULL,
        [TotalRowsAffected] [int] NULL,
        [DeltaRowsAffected] [int] NULL,
    CONSTRAINT [PK_table_usage_stats] PRIMARY KEY CLUSTERED 
    (
        [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
    ) ON [PRIMARY];

    CREATE NONCLUSTERED INDEX [IX_LastActionTime] ON [dbo].[table_usage_stats] 
    (
        [TableName] ASC,
        [LastActionTime] ASC
    )WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
END
'@  
Invoke-Sqlcmd -ServerInstance $servername -Database $databasename -Query $create_table 
Invoke-Sqlcmd -ServerInstance $servername -Database $databasename -Query "DELETE FROM candidates where stage = $stage"

$candidates = Get-Content $inputfile

    
foreach ($candidate in $candidates) {
    if ($candidate -match "\." -eq $true) {
        $schema = $candidate.split(".")[0]
        $name = $candidate.split(".")[1]
    }
    else {
        $schema = "dbo"
        $name = $candidate
    }
    $sql = "insert into candidates (schema_name, procedure_name, stage) values ('$schema','$name',$stage)"
    Invoke-Sqlcmd -ServerInstance $servername -Database $databasename -Query $sql
}

Write-Output "Processing insert-candidates for stage $stage is complete!"

#.\insert-candidates.ps1 -servername "NSUVER-LW" -databasename "performance" -inputfile "C:\Users\nsuver\OneDrive - Southern Connecticut State University\thesis\matrix content\stage1\stage-1-out.txt" -stage 1