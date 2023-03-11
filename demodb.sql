#Example sql script to create DDL objects to a Synapse Serverless database

USE demodb
GO

ALTER DATABASE demodb
    COLLATE Latin1_General_100_BIN2_UTF8

--Script to drop all ext tables to enable dropping and recreating datasource and ext tables
DECLARE @sql NVARCHAR(max)=''
SELECT @sql += ' DROP EXTERNAL TABLE ' + QUOTENAME(TABLE_SCHEMA) + '.'+ QUOTENAME(TABLE_NAME) + '; '
FROM INFORMATION_SCHEMA.TABLES
WHERE  TABLE_TYPE = 'BASE TABLE'
Exec sp_executesql @sql
GO

IF EXISTS(select *
from sys.external_data_sources
where name = 'demoSource')
DROP EXTERNAL DATA SOURCE demoSource
CREATE EXTERNAL DATA SOURCE demoSource WITH (
    LOCATION = 'https://$(datalakeName).blob.core.windows.net/bronze',
    CREDENTIAL = [demodb-credential]
)
GO

IF EXISTS (SELECT *
FROM sys.external_tables
WHERE object_id = OBJECT_ID('Generic'))  
DROP EXTERNAL TABLE  dbo.Generic
CREATE EXTERNAL TABLE dbo.Generic (
	[_id] nvarchar(25),
	[index] int,
	[guid] nvarchar(50),
	[isActive] bit,
	[balance] nvarchar(25),
	[picture] nvarchar(255),
	[age] int,
	[eyeColor] nvarchar(50),
	[name] nvarchar(255),
	[gender] nvarchar(10),
	[company] nvarchar(255),
	[email] nvarchar(255),
	[phone] nvarchar(17),
	[address] nvarchar(255),
	[about] nvarchar(1000),
	[registered] nvarchar(100),
	[latitude] float,
	[longitude] float,
	[greeting] nvarchar(255),
	[favoriteFruit] nvarchar(25),
	[ModifiedDateTime] datetime2(7)
	)
	WITH (
	LOCATION = 'latest/generic/Generic.parquet',
	DATA_SOURCE = [demoSource],
	FILE_FORMAT = [ParquetFormat]
	)
GO

IF EXISTS (SELECT *
FROM sys.external_tables
WHERE object_id = OBJECT_ID('GenericFriends'))  
DROP EXTERNAL TABLE  dbo.GenericFriends
CREATE EXTERNAL TABLE dbo.GenericFriends (
	[id] int,
	[name] nvarchar(255),
	[generic_guid] nvarchar(50),
	[ModifiedDateTime] datetime2(7)
	)
	WITH (
	LOCATION = 'latest/generic/GenericFriends.parquet',
	DATA_SOURCE = [demoSource],
	FILE_FORMAT = [ParquetFormat]
	)
GO

IF EXISTS (SELECT *
FROM sys.external_tables
WHERE object_id = OBJECT_ID('GenericTags'))  
DROP EXTERNAL TABLE  dbo.GenericTags
CREATE EXTERNAL TABLE dbo.GenericTags (
	[tags] nvarchar(255),
	[generic_guid] nvarchar(50),
	[ModifiedDateTime] datetime2(7)
	)
	WITH (
	LOCATION = 'latest/generic/GenericTags.parquet',
	DATA_SOURCE = [demoSource],
	FILE_FORMAT = [ParquetFormat]
	)
GO
