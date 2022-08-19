 # AMS HRNA health check validator for Opera

#defining static variables
$sc_path = "E:\scripts\validator"
$mydate = Invoke-Expression -command "Get-Date -Format MM-dd-yyyy_HH-mm"
$myhost = Invoke-Expression -command '[System.Net.Dns]::GetHostByName((hostname)).HostName'
$hostname = Invoke-Expression -command "hostname"
$myip = Invoke-Expression -command '(gwmi Win32_NetworkAdapterConfiguration | ? { $_.IPAddress -ne $null }).ipaddress'
$opmnctl_dir = "E:\myMicros\Oracle\Middleware\instances\" + $hostname + "_ORCLRNA\bin" 
$mylog = "output_wlst.ini"
$transcript = "transcript_HRNA_" + $hostname + "_" + $mydate + ".txt" 
$check_admin_server = "E:\myMicros\Oracle\Middleware\user_projects\domains\bifoundation_domain\servers\AdminServer\data\nodemanager\AdminServer.state"
$check_bi_server = "E:\myMicros\Oracle\Middleware\user_projects\domains\bifoundation_domain\servers\bi_server2\data\nodemanager\bi_server2.state"
$report= "report_HRNA_"+ $hostname + "_" + $mydate + ".txt"
$myactions = "actions_HRNA_"+ $hostname + "_" + $mydate + ".txt"
$elk_log = "cv_HRNA_"+ $hostname + ".txt"

function ps_version_check {
  Write-Host "[ POWERSHELL VERSION CHECK ]" -ForegroundColor Green
  Write-Host ""
  Get-Host | Select-Object Version > $sc_path\logs\ver.txt
  $ps_ver_1 =  Get-Content $sc_path\logs\ver.txt | Select-Object -last 3
  $ps_ver_2 =  Get-Content $sc_path\logs\ver.txt | Select-Object -last 1
  if( ($ps_ver_1 -lt "3.0") -or ($ps_ver_2 -lt "3.0") ){
   write-host "PS is higher and script will work"
  }else {
   write-host "PS is lower and script will not work, Please upgrade the PowerShell to 3.0 and above"
   break
  }
  write-host ""
}

function Resource_check {
  Write-Host "[ RESOURCE CHECK ]" -ForegroundColor Green
  Write-Host ""
  $properties=@(
     @{Name="Name"; Expression = {$_.name}},
     @{Name="PID"; Expression = {$_.IDProcess}},
     @{Name="CPU (%)"; Expression = {$_.PercentProcessorTime}},
     @{Name="Memory (MB)"; Expression = {[Math]::Round(($_.workingSetPrivate / 1mb),2)}}
     @{Name="Disk (MB)"; Expression = {[Math]::Round(($_.IODataOperationsPersec / 1mb),2)}}
  )
  $ProcessCPU = Get-WmiObject -class Win32_PerfFormattedData_PerfProc_Process |
     Select-Object $properties |
     Sort-Object "CPU (%)" -desc |
     Sort-Object "Memory (MB)" -desc |
     Sort-Object "Disk (MB)" -desc |
     Select-Object -First 10
  $ProcessCPU | Select-Object *,@{Name="Path";Expression = {(Get-Process -Id $_.PID).Path}} | Format-Table
  write-Host ""
}

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
  
function update_py {
  # Update jython script "defaultpassword" and "myhostname" strings
 
  Write-Host("Updating jython scripts ...")
  Write-Host ""

  (Get-Content $sc_path\HRNA_status.py) -replace 'myhostname', "$myhost" | Set-Content $sc_path\HRNA_status.py
  if ($?) { 
     Write-Host("hostname updated successfully!") -ForegroundColor Green
  }else {
    Write-Host("There was a problem updating the credentials in the HRNA_status.py script, exiting ....")
    break
  }
  Write-Host ""
}

function prepare_and_execute {
  # delete previous output files to avoid confusion
  Write-Host("Deleting old report files ...")
  Remove-Item $sc_path\logs\output_*.ini | Out-Null
  Remove-Item $sc_path\logs\*_status.txt | Out-Null
  write-Host "" 

  # execute the HRNA_status.py jython script and capturing its output into our log
  Write-Host("Executing status validator for $myhost, this will take a minute, or two ...")
  Write-Host ""
  if(Test-Path -LiteralPath $check_admin_server -PathType Leaf ){
    write-Host "RUNNING : HRNA_wlst_conn.cmd" -ForegroundColor Yellow
    cmd /c $sc_path\HRNA_wlst_conn.cmd

    Write-Host "[ WLS CONN STATUS ]" -ForegroundColor Green
    Write-Host ""
    # Extract actual values
    # Create array from the input file
    Get-Content $sc_path\logs\$mylog | Select-String "ConnectToWeblogic" -OutVariable Weblogic_conn_status | Out-Null
    $Weblogic_conn_status | ConvertFrom-StringData -OutVariable Weblogic_conn_status2 | Out-Null
 
    $count = $Weblogic_conn_status2.count -1
 
    while($count -ge 0){
     $Weblogic_conn_status2[$count].keys | Out-Null
     $Weblogic_conn_status2[$count].values | Out-Null
 
    if ($Weblogic_conn_status2[$count].values -ne "Failure"){
      Write-Host "PASS: "$Weblogic_conn_status2[$count].keys" weblogic_conn_status is "$Weblogic_conn_status2[$count].values" on SSL" -ForegroundColor Yellow
    }else {
      Write-Host "FAIL $hostname "$Weblogic_conn_status2[$count].keys" weblogic_conn_status is "$Weblogic_conn_status2[$count].values" on SSL" -ForegroundColor Red
    }
    $count -= 1
    }
    Write-Host ""

    Write-Host "[ WLS CHANGE CHECK ]" -ForegroundColor Green
    Write-Host ""
    # Extract actual values
    # Create array from the input file
    Get-Content $sc_path\logs\$mylog | Select-String "Unactivatedchanges" -OutVariable change_status | Out-Null
    $change_status | ConvertFrom-StringData -OutVariable change_status2 | Out-Null
 
    $count = $change_status2.count -1
 
    while($count -ge 0){
     $change_status2[$count].keys | Out-Null
     $change_status2[$count].values | Out-Null
 
    if ($change_status2[$count].values -eq "NOT_PRESENT"){
      Write-Host "PASS: "$change_status2[$count].keys" change-status is "$change_status2[$count].values"" -ForegroundColor Yellow
    }else {
      Write-Host "FAIL $hostname "$change_status2[$count].keys" change-status is "$change_status2[$count].values"" -ForegroundColor Red
    }
    $count -= 1
    }
    Write-Host ""

    Write-Host "[ SERVER STATUS CHECK ]" -ForegroundColor Green
    Write-Host ""
   
    # Extract actual values
    # Create array from the input file
    Get-Content $sc_path\logs\$mylog | Select-String "ServerStatus" -OutVariable server_status | Out-Null
    $server_status | ConvertFrom-StringData -OutVariable server_status2 | Out-Null
   
    $count = $server_status2.count -1
   
    while($count -ge 0){
       $server_status2[$count].keys | Out-Null
       $server_status2[$count].values | Out-Null
   
     if ($server_status2[$count].values -eq "RUNNING"){
        Write-Host "PASS: "$server_status2[$count].keys" server-status is "$server_status2[$count].values"" -ForegroundColor Yellow
      }else {
        Write-Host "FAIL $hostname "$server_status2[$count].keys" server-status is "$server_status2[$count].values"" -ForegroundColor Red
     }
    $count -= 1
    }
    Write-Host ""
    
    Write-Host "[ APPLICATION STATUS HEALTH CHECK ]" -ForegroundColor Green
    Write-Host ""
 
   # Extract actual values
   # Create array from the input file
   Get-Content $sc_path\logs\$mylog | Select-String "AppStatus" -OutVariable app_health | Out-Null
   $app_health | ConvertFrom-StringData -OutVariable app_health2 | Out-Null
 
   $count = $app_health.count -1
 
   while($count -ge 0){
     $app_health2[$count].keys | Out-Null
     $app_health2[$count].values | Out-Null
 
   if ($app_health2[$count].values -match "STATE_ACTIVE"){
      Write-Host "PASS: "$app_health2[$count].keys" status is "$app_health2[$count].values"" -ForegroundColor Yellow
    }else {
      Write-Host "FAIL $hostname "$app_health2[$count].keys" status is not "$app_health2[$count].values"" -ForegroundColor Red
   }
    $count -= 1
   }
   Write-Host ""

   Write-Host "[ APPLICATION DEPLOYMENT HEALTH CHECK ]" -ForegroundColor Green
   Write-Host ""
  
   # Extract actual values
   # Create array from the input file
   Get-Content $sc_path\logs\$mylog | Select-String "AppHealth" -OutVariable deployment_health | Out-Null
   $deployment_health | ConvertFrom-StringData -OutVariable deployment_health2 | Out-Null
  
   $count = $deployment_health2.count -1
  
   while($count -ge 0){
      $deployment_health2[$count].keys | Out-Null
      $deployment_health2[$count].values | Out-Null
  
    if ($deployment_health2[$count].values -match "HEALTH_OK"){
       Write-Host "PASS: "$deployment_health2[$count].keys" status is "$deployment_health2[$count].values"" -ForegroundColor Yellow
     }else {
       Write-Host "FAIL $hostname "$deployment_health2[$count].keys" status is not "$deployment_health2[$count].values"" -ForegroundColor Red
    }
    $count -= 1
    }
    Write-Host ""
    
    Write-Host "[ DATASOURCE CONNECTION CHECK ]" -ForegroundColor Green
    Write-Host ""
   
    # Extract actual values
    # Create array from the input file
    Get-Content $sc_path\logs\$mylog | Select-String "TestDatasource" -OutVariable ds_conn | Out-Null
    $ds_conn | ConvertFrom-StringData -OutVariable ds_conn2 | Out-Null
   
    $count = $ds_conn2.count -1
   
    while($count -ge 0){
       $ds_conn2[$count].keys | Out-Null
       $ds_conn2[$count].values | Out-Null
   
     if ($ds_conn2[$count].values -match "OK"){
        Write-Host "PASS: "$ds_conn2[$count].keys" status is "$ds_conn2[$count].values"" -ForegroundColor Yellow
      }else {
        Write-Host "FAIL $hostname "$ds_conn2[$count].keys" status is not "$ds_conn2[$count].values"" -ForegroundColor Red
     }
    $count -= 1
    }
    Write-Host ""  

  }else {
    Write-Host "problem runnig WLST script or not an admin server, continuing ..." -ForegroundColor Red
    Write-Host ""
  }
  Write-Host ""
}

function Analytics_Server_Status {
  Write-Host "[ Analytics_Server_Status ]" -ForegroundColor Green
  Write-Host ""

  if( (Test-Path -LiteralPath $check_admin_server -PathType Leaf) -or (Test-Path -LiteralPath $check_bi_server -PathType Leaf) ){
    [string[]]$sites = ( 
     "https://$myhost/analytics/saw.dll?admin"
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    foreach ($site in $sites)
     {
      try {
      $status = (Invoke-WebRequest -Uri $site -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
      Write-Host "PASS : $Site status code $status" -ForegroundColor Yellow
      }
      catch {
      Write-Host "FAIL $hostname $Site" -ForegroundColor Red
      }
    }
   }else {
    Write-Host "This is an Portal server not OBIEE" -ForegroundColor Green
   } 
   Write-Host ""
 } 
 

 function Portal_status {
 Write-Host "[ Portal_status ]" -ForegroundColor Green
  Write-Host ""

  if( (Test-Path -LiteralPath $check_admin_server -PathType Leaf) -or (Test-Path -LiteralPath $check_bi_server -PathType Leaf) ){
    Write-Host "This is an OBIEE server not Portal" -ForegroundColor Green
  }else {
   [string[]]$sites = ( 
     "https://" + $myip + ":443"
   )
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   foreach ($site in $sites)
    {
     try {
       $status = (Invoke-WebRequest -Uri $site -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode 
       Write-Host "PASS : $Site status code $status" -ForegroundColor Yellow
     }
     catch {
       Write-Host "FAIL $hostname $Site" -ForegroundColor Red
     }
    }
   }
   Write-Host ""
 } 
 
function opmnctl_status {
  Write-Host "[ opmnctl_status ]" -ForegroundColor Green
  Write-Host ""

  if(Test-Path -LiteralPath $check_admin_server -PathType Leaf){
    write-Host "RUNNING : opmnctl_status" -ForegroundColor Yellow
    Write-Host "DIR : $opmnctl_dir"
    Invoke-Expression -command "$opmnctl_dir\opmnctl.bat status"
  }else {
    Write-Host " Not an OBIEE admin server and opmnctl not present" -ForegroundColor Yellow
  }
  Write-Host ""
}
function portal_service_status{
  Write-Host "[ portal_service_status ]" -ForegroundColor Green
  Write-Host "" 
  
  if( (Test-Path -LiteralPath $check_admin_server -PathType Leaf) -or (Test-Path -LiteralPath $check_bi_server -PathType Leaf) ){
     Write-Host "This is an OBIEE server not Portal" -ForegroundColor Green
   }else {
    $Service1 = 'AdminServer'
    $Service2 = 'InfoDeliveryServiceWrapper'
    $services = @(
    $Service1,
    $Service2 )
    foreach($ServiceName in $Services)
   {
   $arrService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
   if ($arrService.Length -gt 0){
    if ($arrService.Status -eq 'Running')
        {
          Write-Host "PASS : $ServiceName Service is Running" -ForegroundColor Yellow
        }else {
          Write-Host "FAIL : $ServiceName Service is not Running" -ForegroundColor Red
        }
     }else {
        Write-Host "$ServiceName doesn't exist" -ForegroundColor Yellow
      }
    }
  Write-Host "" 
 }
} 

function revert_py {
  # Update jython script "defaultpassword" and "myhostname" strings
 
  Write-Host("revert jython scripts ...")
  Write-Host ""
  (Get-Content $sc_path\HRNA_status.py) -replace "$myhost", 'myhostname' | Set-Content $sc_path\HRNA_status.py
  if ($?) { 
     Write-Host("hostname reverted successfully!") -ForegroundColor Green
  }else {
    Write-Host("There was a problem reverting the hostname in the HRNA_status.py script") -ForegroundColor Red
  }
  Write-Host ""
}

function script_logger_config {
  Select-String -Pattern "FAIL" $sc_path\output\$transcript | Select-Object line | Out-File $sc_path\output\$myactions
  Select-String -CaseSensitive -Pattern 'FAIL', 'PASS', 'INFO', 'WARNING' $sc_path\output\$transcript | Select-Object line | Out-File $sc_path\output\$report
  Write-Host "***** Execution completed!" -ForegroundColor Yellow
  Write-Host "***** For FULL TRANSCRIPT file, access: $sc_path\output\$transcript" -ForegroundColor Yellow
  Write-Host "***** For FAILED ITEMS quick review, access: $sc_path\output\$myactions" -ForegroundColor Red
  Write-Host "***** For a QUICK LIST OF ALL ITEMS items review, access: $sc_path\output\$report" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "***** Total number of evaluated Items:" -ForegroundColor Yellow
  @(Get-Content $sc_path\output\$report).Length
  Write-Host ""
  Write-Host "***** Total number of failed Items:" -ForegroundColor Red
  @(Get-Content $sc_path\output\$myactions).Length 
}
function artifactory_upload {
  if(Test-Path -LiteralPath $sc_path\output\$transcript -PathType Leaf ){
    try
   {
      #Uploading Logs to APAC Jfrog Artifactory
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      curl -H @{'X-JFrog-Art-Api' = 'AKCp5fTttwFj8ZUL7mS6skVrGfpa1th7Zx4iA3XM15ZwQ5oF7gPVUZShBU3H8qj42F2DdGbPf'} -method PUT -InFile "$sc_path\output\$transcript" "https://artifactory.int.oracleindustry.com/artifactory/hgbu-depot/AMS/windows_validator/$transcript" | Out-Null
      Write-Host "Logs uploaded to APAC Artifactory. Please find the logs under https://artifactory.int.oracleindustry.com/artifactory/hgbu-depot/AMS/windows_validator" -ForegroundColor Yellow
      Write-Host ""
   }
   catch
   {
      #If unable to upload logs to APAC artifactory
      Write-Host "Check APAC artifactory is correct or not"
   }
   try
   {
      #Uploading Logs to IAD Jfrog Artifactory
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      curl -H @{'X-JFrog-Art-Api' = 'AKCp5fTjaXgyKWcukkVsyvbt7k4GYGsTAb1RX5ZP6TFWVS3BaaUa4VxgqDY4J4JBWMpKPYShW'} -method PUT -InFile "$sc_path\output\$transcript" "https://artifactory-av.oracleindustry.com/artifactory/hgbu-depot/AMS/windows_validator/$transcript" | Out-Null
      Write-Host "Logs uploaded to IAD Artifactory. Please find the logs under https://artifactory-av.oracleindustry.com/artifactory/hgbu-depot/AMS/windows_validator" -ForegroundColor Yellow
      Write-Host ""
   }
   catch
   {
      #If unable to upload logs to IAD artifactory
      Write-Host "Check IAD artifactory correct or not"
   }
 
   try
   {
      #Uploading Logs to FR Jfrog Artifactory
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      curl -H @{'X-JFrog-Art-Api' = 'AKCp5dLCRdsnPibNFG7NARoNdjgMd4fuajMiT87jJghgjfbo6dC9yvt4UBZeetjh5VKAAVk9t'} -method PUT -InFile "$sc_path\output\$transcript" "https://artifactory-fg.int.oracleindustry.com/artifactory/list/hgbu-depot/AMS/windows_validator/$transcript" | Out-Null
      Write-Host "Logs uploaded to FR Artifactory. Please find the logs under https://artifactory-fg.int.oracleindustry.com/artifactory/hgbu-depot/AMS/windows_validator" -ForegroundColor Yellow
      Write-Host ""
   }
   catch
   {
      #If unable to upload logs to FR artifactory
      Write-Host "Check FR artifactory correct or not"
   }
  }else {
   Write-Host "No summary report found in $myhost"
  }
 }
function check_failure {
  $fail_cnt = @(Get-Content $sc_path\output\$myactions).Length
  try {
   if ($fail_cnt -ne "0"){
     write-host "some components are failed, please check $sc_path\output\$myactions and continue further .. Exiting the script" -ForegroundColor Red
     Invoke-Item $sc_path\output\$myactions
     Get-Content "$sc_path\output\$myactions" | Where-Object { $_ -Match "FAIL"} | Where-Object { $_ -NotMatch "----"} | Where-Object { $_ -NotMatch "Line"} | Where-Object { $_ -NotMatch "<"} | Out-File -Encoding ascii $sc_path\logs\$elk_log
     Start-Sleep -s 10
     Move-Item -Path $sc_path\output\*.txt -Destination $sc_path\logs -Force
     Get-Process OpenWith -ErrorAction SilentlyContinue | Stop-Process -PassThru -Force
     exit 1
    } else{
     write-host "All Fine" -ForegroundColor Green
     Write-Output "NO HC ERRORS found for $hostname on $mydate" | Out-File -Encoding ascii $sc_path\logs\$elk_log
     Start-Sleep -s 10
     Move-Item -Path $sc_path\output\*.txt -Destination $sc_path\logs -Force
     Get-Process OpenWith -ErrorAction SilentlyContinue | Stop-Process -PassThru -Force
    }
   }catch {
     exit 1
   }
}

# Function Execution Flow
ps_version_check
update_py
Start-Transcript $sc_path\output\$transcript -Append | Out-Null
Resource_check
prepare_and_execute
Analytics_Server_Status 
Portal_status
opmnctl_status
portal_service_status
Stop-Transcript | Out-Null
revert_py
script_logger_config
artifactory_upload
check_failure 
