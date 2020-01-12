/***************************************************
TraceCaptureDef, originally written by Microsoft, (c) Oct 2008.  Modified to filter procedures that were documented in stage 3 of our filtering process

October 2008

This file is the RML Utility Replay capture definition for the following SQL Server versions:

     SQL Server 2000
     SQL Server 2005
     SQL Server 2008

This trace definition provides capture support for replay and full reporting functionality.

Instructions
============

Change the InsertFileNameHere to a file name prefixed by a path that is high speed local disk.  
Do not add the .TRC extension, the server will add it for you.  e.g., 'C:\temp\MyServer_sp_trace'

Note:  It is normal if you get error that #tmpPPEventEnable does not exist
       the first time you run this script.

***************************************************/
--drop procedure #tmpPPEventEnable
--go


create procedure #tmpPPEventEnable  @TraceID int, @iEventID int
as
begin
	set nocount on

	declare @iColID		int
	declare @iColIDMax	int
	declare @on bit

	set @on= 1
	set @iColID = 1
	set @iColIDMax = 64

	while(@iColID <= @iColIDMax)
	begin
		exec sp_trace_setevent @TraceID, @iEventID, @iColID, @on
		set @iColID = @iColID + 1
	end
end
go


-- Create a Queue
declare @path nvarchar(500) = N'c:\temp\dev.trc'
declare @DatabaseName nvarchar(100) = N'SonetoDevelopment'
declare @rc int
declare @TraceID int
declare @maxfilesize bigint
set @maxfilesize = 250				--	An optimal size for tracing and handling the files

-- Please replace the text InsertFileNameHere, with an appropriate
-- file name prefixed by a path, e.g., c:\MyFolder\MyTrace. The .trc extension
-- will be appended to the filename automatically. 

exec @rc = sp_trace_create @TraceID output, 2 /* rollover*/, @path , @maxfilesize, NULL 
if (@rc != 0) goto error

declare @off bit
set @off = 0

-- Set the events
exec #tmpPPEventEnable @TraceID, 10  --  RPC Completed
exec #tmpPPEventEnable @TraceID, 11  --  RPC Started

declare @strVersion varchar(10)

set @strVersion = cast(SERVERPROPERTY('ProductVersion') as varchar(10))
if( (select cast( substring(@strVersion, 0, charindex('.', @strVersion)) as int)) >= 9)
begin
	exec sp_trace_setevent @TraceID, 10, 1, @off		--		No Text for RPC, only Binary for performance
	exec sp_trace_setevent @TraceID, 11, 1, @off		--		No Text for RPC, only Binary for performance
end
/*
exec #tmpPPEventEnable @TraceID, 44  --  SP:StmtStarting
exec #tmpPPEventEnable @TraceID, 45  --  SP:StmtCompleted
exec #tmpPPEventEnable @TraceID, 100 --  RPC Output Parameter

exec #tmpPPEventEnable @TraceID, 12  --  SQL Batch Completed
exec #tmpPPEventEnable @TraceID, 13  --  SQL Batch Starting
exec #tmpPPEventEnable @TraceID, 40  --  SQL:StmtStarting
exec #tmpPPEventEnable @TraceID, 41  --  SQL:StmtCompleted

exec #tmpPPEventEnable @TraceID, 17  --  Existing Connection
exec #tmpPPEventEnable @TraceID, 14  --  Audit Login
exec #tmpPPEventEnable @TraceID, 15  --  Audit Logout

exec #tmpPPEventEnable @TraceID, 16  --  Attention

exec #tmpPPEventEnable @TraceID, 19  --  DTC Transaction
exec #tmpPPEventEnable @TraceID, 50  --  SQL Transaction
exec #tmpPPEventEnable @TraceID, 50  --  SQL Transaction
exec #tmpPPEventEnable @TraceID, 181 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 182 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 183 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 184 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 185 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 186 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 187 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 188 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 191 --  Tran Man Event
exec #tmpPPEventEnable @TraceID, 192 --  Tran Man Event

exec #tmpPPEventEnable @TraceID, 98  --  Stats Profile

exec #tmpPPEventEnable @TraceID, 53  --  Cursor Open
exec #tmpPPEventEnable @TraceID, 70  --  Cursor Prepare
exec #tmpPPEventEnable @TraceID, 71  --  Prepare SQL
exec #tmpPPEventEnable @TraceID, 73  --  Unprepare SQL
exec #tmpPPEventEnable @TraceID, 74  --  Cursor Execute
exec #tmpPPEventEnable @TraceID, 76  --  Cursor Implicit Conversion
exec #tmpPPEventEnable @TraceID, 77  --  Cursor Unprepare
exec #tmpPPEventEnable @TraceID, 78  --  Cursor Close

exec #tmpPPEventEnable @TraceID, 22  --  Error Log
exec #tmpPPEventEnable @TraceID, 25  --  Deadlock
exec #tmpPPEventEnable @TraceID, 27  --  Lock Timeout
exec #tmpPPEventEnable @TraceID, 60  --  Lock Escalation
exec #tmpPPEventEnable @TraceID, 28  --  MAX DOP
exec #tmpPPEventEnable @TraceID, 33  --  Exceptions
exec #tmpPPEventEnable @TraceID, 34  --  Cache Miss
exec #tmpPPEventEnable @TraceID, 37  --  Recompile
--exec #tmpPPEventEnable @TraceID, 39  --  Deprocated Events
exec #tmpPPEventEnable @TraceID, 55  --  Hash Warning
exec #tmpPPEventEnable @TraceID, 58  --  Auto Stats
exec #tmpPPEventEnable @TraceID, 67  --  Execution Warnings
exec #tmpPPEventEnable @TraceID, 69  --  Sort Warnings
exec #tmpPPEventEnable @TraceID, 79  --  Missing Col Stats
exec #tmpPPEventEnable @TraceID, 80  --  Missing Join Pred
exec #tmpPPEventEnable @TraceID, 81  --  Memory change event
exec #tmpPPEventEnable @TraceID, 92  --  Data File Auto Grow
exec #tmpPPEventEnable @TraceID, 93  --  Log File Auto Grow
exec #tmpPPEventEnable @TraceID, 116 --  DBCC Event
exec #tmpPPEventEnable @TraceID, 125 --  Deprocation Events
exec #tmpPPEventEnable @TraceID, 126 --  Deprocation Final
exec #tmpPPEventEnable @TraceID, 127 --  Spills
exec #tmpPPEventEnable @TraceID, 137 --  Blocked Process Threshold
exec #tmpPPEventEnable @TraceID, 150 --  Trace file closed
exec #tmpPPEventEnable @TraceID, 166 --  Statement Recompile

181	12	TM: Begin Tran starting
182	12	TM: Begin Tran completed
183	12	TM: Promote Tran starting
184	12	TM: Promote Tran completed
185	12	TM: Commit Tran starting
186	12	TM: Commit Tran completed
187	12	TM: Rollback Tran starting
188	12	TM: Rollback Tran completed
191	12	TM: Save Tran starting
192	12	TM: Save Tran completed
*/
if(exists (select * from sys.trace_events where name = 'TM: Begin Tran starting'))
begin
	exec #tmpPPEventEnable @TraceID, 181
	exec #tmpPPEventEnable @TraceID, 182
	exec #tmpPPEventEnable @TraceID, 183
	exec #tmpPPEventEnable @TraceID, 184
	exec #tmpPPEventEnable @TraceID, 185
	exec #tmpPPEventEnable @TraceID, 186
	exec #tmpPPEventEnable @TraceID, 187
	exec #tmpPPEventEnable @TraceID, 188
	exec #tmpPPEventEnable @TraceID, 191
	exec #tmpPPEventEnable @TraceID, 192
end

exec #tmpPPEventEnable @TraceID, 196 --  CLR Assembly Load

--	Filter out all sp_trace based commands to the replay does not start this trace
--	Text filters can be expensive so you may want to avoid the filtering and just
--	remote the sp_trace commands from the RML files once processed.
exec sp_trace_setfilter @TraceID, 1, 1, 7, N'%sp_trace%' --exclude trace calls from our trace
declare @candidate nvarchar(500)
DECLARE candidate_cursor CURSOR FORWARD_ONLY READ_ONLY FOR 
SELECT procedure_name FROM candidates WHERE stage = 3 
OPEN candidate_cursor
FETCH NEXT FROM candidate_cursor INTO @candidate
WHILE @@FETCH_STATUS = 0
BEGIN
	exec sp_trace_setfilter @TraceID, 35, 1, 6, N'%' + @candidate + '%' --only consider tracing our stage 3 candidates
	FETCH NEXT FROM candidate_cursor INTO @candidate
END
CLOSE candidate_cursor
DEALLOCATE candidate_cursor




exec sp_trace_setfilter @TraceID, 35, 0, 0, @DatabaseName

-- Set the trace status to start
exec sp_trace_setstatus @TraceID, 1

/*
exec sp_trace_setstatus 2, 0
exec sp_trace_setstatus 2, 2
*/
print 'Issue the following command(s) when you are ready to stop the tracing activity'
print 'exec sp_trace_setstatus ' + cast(@TraceID as varchar) + ', 0'
print 'exec sp_trace_setstatus ' + cast(@TraceID as varchar) + ', 2'

goto finish

error: 
select ErrorCode=@rc

finish: 
--select * from ::fn_trace_geteventinfo(@TraceID)
select * from sys.traces
GO
--when stopping:
