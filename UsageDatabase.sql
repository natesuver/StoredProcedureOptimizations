USE [master]
GO
/****** Object:  Database [usage]    Script Date: 9/13/2019 2:34:09 PM ******/
CREATE DATABASE [usage] ON  PRIMARY 
( NAME = N'usage', FILENAME = N'c:\sql\usage.mdf' , SIZE = 768000KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'usage_log', FILENAME = N'c:\sql\usage_log.ldf' , SIZE = 3860032KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO

USE [usage]
GO
/****** Object:  Table [dbo].[tracked_tables]    Script Date: 9/13/2019 2:34:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tracked_tables](
	[StudyNumber] [int] NOT NULL,
	[TableName] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_tracked_tables] PRIMARY KEY CLUSTERED 
(
	[StudyNumber] ASC,
	[TableName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[usage_stats]    Script Date: 9/13/2019 2:34:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[usage_stats](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[TableName] [nvarchar](50) NOT NULL,
	[ProcessTime] [datetime] NULL,
	[ActionType] [tinyint] NULL,
	[LastActionTime] [datetime] NULL,
	[TotalRowsAffected] [int] NULL,
	[DeltaRowsAffected] [int] NULL,
 CONSTRAINT [PK_usage_stats] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_TableName_Time]    Script Date: 9/13/2019 2:34:12 PM ******/
CREATE NONCLUSTERED INDEX [IX_TableName_Time] ON [dbo].[usage_stats]
(
	[TableName] ASC,
	[LastActionTime] ASC,
	[ActionType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

USE [master]
GO
ALTER DATABASE [usage] SET  READ_WRITE 
GO
