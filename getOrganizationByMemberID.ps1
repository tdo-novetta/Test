Function truncateDatabase  ()
{

## ---------------------------------------------------------------------------------------------------------------- ##
## Organizations from Rest API and store in table
## ---------------------------------------------------------------------------------------------------------------- ##

$xmlSetting = [System.Xml.XmlDocument](Get-Content "C:\Program Files\WindowsPowerShell\Modules\ACN_MSPSAutomation\ACN_MSPSAutomation.ps1xml");
$xmlSettingFile = $xmlSetting.Configuration.AgileSettingFile
$xmlSettingDoc = [System.Xml.XmlDocument](Get-Content $xmlSettingFile);

$DBName = $xmlSettingDoc.Agile.Configuration.DevOps.DBName
$DBServer = $xmlSettingDoc.Agile.Configuration.DevOps.DBServer
$myQuery = "TRUNCATE TABLE [AFS_CS_Admin].[dbo].[AFS_ADO_Organizations]"

    TRY
    {
        $sqlConnection=new-object System.Data.SqlClient.SQLConnection    
        $sqlConnection.ConnectionString = "server=" + $DBServer +";database=" + $DBName + ";trusted_connection=true;";  
        $sqlConnection.Open()    

        $sql = $myQuery
        #$sql
        $cmd=new-object system.Data.SqlClient.SqlCommand($sql,$sqlConnection) 
        $cmd.ExecuteNonQuery() | OUt-Null
        
        getAccountsByMemberID
			
    }
    catch [System.Data.SqlClient.SqlException] 
    { 
            # A SqlException occurred. According to documentation, this happens when a command is executed against a locked row. 
            write-Host "SQL error." 
			
			write-host $_.Exception.ToString() -foregroundcolor "red"	
    } 
    catch 
    { 
			write-host $_.Exception.ToString() -foregroundcolor "red"	
            # An generic error occurred somewhere in the try area. 
            write-Host "An error occurred while attempting to open the database connection and execute a command when deleting" 
    } 
    finally 
    { 
            # Determine if the connection was opened. 
            if ($sqlConnection.State -eq "Open") 
            { 
                # Close the currently open connection. 
                $sqlConnection.Close() 
            } 
    }
}

Function getAccountsByMemberID ()
{
[CmdletBinding()]
    
## ---------------------------------------------------------------------------------------------------------------- ##
## Get organizations by memberID.  Will change to by tenant id in the future
## ---------------------------------------------------------------------------------------------------------------- ##

$xmlSetting = [System.Xml.XmlDocument](Get-Content "C:\Program Files\WindowsPowerShell\Modules\ACN_MSPSAutomation\ACN_MSPSAutomation.ps1xml");
$xmlSettingFile = $xmlSetting.Configuration.AgileSettingFile
$xmlSettingDoc = [System.Xml.XmlDocument](Get-Content $xmlSettingFile);

$DBName = $xmlSettingDoc.Agile.Configuration.DevOps.DBName
$DBServer = $xmlSettingDoc.Agile.Configuration.DevOps.DBServer

$AdminUser = $xmlSettingDoc.Agile.Configuration.DevOps.AdminUser
$Token = Get-Content "E:\AgileTools\Encryption\AzureDevOps.txt" | ConvertTo-SecureString -key (Get-Content "E:\AgileTools\Encryption\AzureDevOps.key") | ForEach-Object {[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))}

##Write-host $xmlSettingDoc 
##write-Host "DBName: $DBName DBServer: $DBServer - getting Member/License data for $Org"


# The Header is created with the given information.
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $AdminUser, $Token)))
$Header = @{
    Authorization = ("Basic {0}" -f $base64AuthInfo)
}

# Splat the parameters in a hashtable for readability
$UsersParameters = @{
    Method  = "GET"
    Headers = $Header
    Uri = "https://app.vssps.visualstudio.com/_apis/accounts?memberId=ae889eb9-d2d0-4518-a225-928d2316f0e5&api-version=6.0" 
    
}


## below addded to force script to run using TLS1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# 
#Write-Host "calling API"
$Accounts = (Invoke-RestMethod @UsersParameters).value ## can put here or during for loop below
#Write-Host "after calling API"

#$Accounts | ConvertTo-Json

## Not sure why the select only works on accountName
#$Accounts | Select accountName,accountId
#$Accounts | Select accountUri 
#$name |foreach{ $Accounts.value.accountName}

#$Accounts | Get-Member  ## tells you the object type

# Create a readable output
$Output = [System.Collections.ArrayList]@()
#$Accounts.value | ForEach-Object {
$Accounts | ForEach-Object {
    $UserObject = [PSCustomObject]@{

        accountName = $_.accountName
        accountId = $_.accountId
       ## accountUri = $_.accountUri
        accountType = $_.accountType
     
   }
    [void]$Output.Add($UserObject)
    ##Write-Verbose "$($UserObject.accountName)" -Verbose
    ##Write-Host ""acctn-$($UserObject.accountName)
    Write-Output $($UserObject.accountName) >> $FileInput
   TRY
    {
        $sqlConnection=new-object System.Data.SqlClient.SQLConnection    
        $sqlConnection.ConnectionString = "server=" + $DBServer +";database=" + $DBName + ";trusted_connection=true;";  
        $sqlConnection.Open()    

        $sql = "INSERT INTO [dbo].[AFS_ADO_Organizations]([Account], [AccountID] ,[ReportDate])
     VALUES
     
        ('$($UserObject.accountName)', '$($UserObject.accountId)', getDate());"
        ##$sql
        $cmd=new-object system.Data.SqlClient.SqlCommand($sql,$sqlConnection) 
        $cmd.ExecuteNonQuery() | OUt-Null
        
			
    }
    catch [System.Data.SqlClient.SqlException] 
    { 
            # A SqlException occurred. According to documentation, this happens when a command is executed against a locked row. 
            write-Host "SQL error." 
            Return
			
			write-host $_.Exception.ToString() -foregroundcolor "red"	
    } 
    catch 
    { 
			write-host $_.Exception.ToString() -foregroundcolor "red"	
            # An generic error occurred somewhere in the try area. 
            write-Host "An error occurred while attempting to open the database connection and execute a command." 
    } 
    finally 
    { 
            # Determine if the connection was opened. 
            if ($sqlConnection.State -eq "Open") 
            { 
                # Close the currently open connection. 
                $sqlConnection.Close() 
            } 
    

        #syncPODCWithMIM -Email $Email 
    }
    
}

##$Output

#Write-Host "output $accountUri[1] -foregroundcolor "yellow"
Write-Host "Count" $Accounts.count

##$accountInfo  ## Uncomment to get list may have to convert to json

}


## ------------------------------------------------------------------------------------------------- ##
## Main
## Author: Elizabeth Johnson
## Tool: Azure DevOps
## Steps:
## Delete from org table
## Calls API to get org information 
##
## ------------------------------------------------------------------------------------------------- ##
$xmlSetting = [System.Xml.XmlDocument](Get-Content "C:\Program Files\WindowsPowerShell\Modules\ACN_MSPSAutomation\ACN_MSPSAutomation.ps1xml");
$xmlSettingFile = $xmlSetting.Configuration.AgileSettingFile
$xmlSettingDoc = [System.Xml.XmlDocument](Get-Content $xmlSettingFile);   

$LogFilePath = $xmlSettingDoc.Agile.Configuration.DevOps.LogFilePath
$LogTime = Get-Date -Format yyyy-MM-dd_h-mm
$Filename = $LogFilePath + "\OrgProject\getAccountsByMemberID" + "-" + $LogTime + ".txt"
$FileInput = "E:\AgileTools\data\org.csv"
$LogFile = Enable-LogFile -Path $Filename

$sendEmail = "No"


Write-Host " .. Start of script $LogTime LogFile $Filename" -ForegroundColor Yellow

if (Test-Path $FileName) {
  Remove-Item $FileName
  Write-Host "deleted $FileName"
  Write-Output "org" >> $FileInput
}else{
Write-Host "$fileName does not exist"
}
#-------------------#
truncateDatabase
#-------------------#

Write-Host " ..End of script $LogTime" -ForegroundColor Yellow
$LogFile | Disable-LogFile