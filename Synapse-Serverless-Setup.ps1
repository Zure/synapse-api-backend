#Example powershell script to deploy synapse databases 

[CmdletBinding()]
param (
    $SynapseServerless,
    $SQLAdminUserName,
    $SQLAdminPassword,
    $PipelineWorkspace,
    $DatalakeName,
    $SQLUserPassword
)

$synapseServerless = $SynapseServerless
$sqlAdminUsername = $SQLAdminUserName
$sqlAdminPassword = $SQLAdminPassword
$pipelineWorkspace = $PipelineWorkspace
$datalakeName = "datalakeName = $DatalakeName"
$sqlUserPassword = $SQLUserPassword

#Function to execute SQL Scripts
function ExecuteSqlScripts([string] $query, [string] $database){
        
        try
        {
            #Execute SQL Scripts
            if($query)
            {
                Invoke-Sqlcmd -Query $query -Variable $datalakeName -ServerInstance "$synapseServerless-ondemand.sql.azuresynapse.net" -Database $database -Username $sqlAdminUsername -Password $sqlAdminPassword -QueryTimeout 120 -ErrorAction 'Stop'
            }
            else 
            {
                Write-Host "No SQL Scripts Found."
            }
        }
        catch
        {
            #Error Logging
            Write-Host "##vso[task.LogIssue type=error;]Error message : $error, Database: $database"
            throw
            exit(1)
        }
        finally
        {
            #Close the DB connections
            [System.Data.SqlClient.SqlConnection]::ClearAllPools()
        }

}

#Loop through the databases list file to create necessary DB objects for each DB
$databases = Get-Content -Path "$pipelineWorkspace/SynapseAPIBackendDemo/Deployment/Scripts/SynapseDBs.json" | ConvertFrom-Json
ForEach ($database in $databases.databases) 
{

#Create the database itself to the Serverless instance
$createDatabase = "IF NOT EXISTS(SELECT [name] FROM sys.databases WHERE [name] = '$database')`n BEGIN `n CREATE DATABASE $database `n END `n GO"
ExecuteSqlScripts $createDatabase "MASTER"

#Create a database master key as per necessitated by syntax
$createMasterKeyEncryption = "IF NOT EXISTS(SELECT [name] from sys.symmetric_keys WHERE [name] = '##MS_DatabaseMasterKey##')`n BEGIN `n CREATE MASTER KEY `n END `n GO"
ExecuteSqlScripts $createMasterKeyEncryption $database

#Create a database login 
$createDatabaseLogin = "IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE [name] = 'examplelogin') CREATE LOGIN [examplelogin] WITH PASSWORD='$sqlUserPassword';"
ExecuteSqlScripts $createDatabaseLogin $database

#Create a database principal that integrations can use to interact with DB
$createDatabasePrincipal = "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE [name] = 'examplelogin')`n BEGIN `n CREATE USER [examplelogin] FOR LOGIN [examplelogin]`n ALTER ROLE db_datareader ADD MEMBER [examplelogin] `n END `n GO"
ExecuteSqlScripts $createDatabasePrincipal $database

#Create a database scoped credential for granting data lake access for the db query
$createScopedCredential = "IF NOT EXISTS(SELECT [name] from sys.database_scoped_credentials WHERE [name] = '$database-credential')`n BEGIN `n CREATE DATABASE SCOPED CREDENTIAL [$database-credential] WITH IDENTITY = 'Managed Identity'; GRANT REFERENCES ON DATABASE SCOPED CREDENTIAL::[$database-credential] TO [examplelogin] `n END `n GO"
ExecuteSqlScripts $createScopedCredential $database

#Create parquet file format to be used in the DB to read parquet files in data lake
$createParquetFormat = "IF NOT EXISTS(select * from sys.external_file_formats where name = 'ParquetFormat') `n BEGIN `n CREATE EXTERNAL FILE FORMAT ParquetFormat WITH `n(FORMAT_TYPE = PARQUET, DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec') `n END `n GO"
ExecuteSqlScripts $createParquetFormat $database

#Create a database schema for access granularity (activate if needed)
#$createSchema = "IF NOT EXISTS(SELECT [name] FROM sys.schemas WHERE [name] = '$database')`n BEGIN `n EXEC('CREATE SCHEMA [$database]) `n END `n GO"
#ExecuteSqlScripts $createSchema $database

#Check if given DB has DDL file in place and create the external tables and data source
if (Test-Path "$pipelineWorkspace/SynapseAPIBackendDemo/Deployment/Scripts/$database.sql")
{
$createExternalTablesAndDataSource = Get-Content -Raw -Path "$pipelineWorkspace/SynapseAPIBackendDemo/Deployment/Scripts/$database.sql"
ExecuteSqlScripts $createExternalTablesAndDataSource $database
}
else {
    Write-Host "The database '$database' could not be deployed because it does not have DDL scripts in the Synapse folder."
}
}
