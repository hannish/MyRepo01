  # AMS v5.5 health check validator for Opera

#defining static variables
$sc_path = "D:\scripts\validator"
$mydate = Invoke-Expression -command "Get-Date -Format MM-dd-yyyy_HH-mm"
$myhost = Invoke-Expression -command '[System.Net.Dns]::GetHostByName((hostname)).HostName'
$hostname = Invoke-Expression -command "hostname"
$mylog = "output_wlst.ini"
$transcript = "transcript_v55_" + $hostname + "_" + $mydate + ".txt" 
$check_admin_server = "D:\ORA\user_projects\domains\OperaDomain\servers\AdminServer\data\nodemanager\AdminServer.state"
$report= "report_v55_"+ $hostname + "_" + $mydate + ".txt"
$myactions = "actions_v55_"+ $hostname + "_" + $mydate + ".txt"
$wls_ssl = "t3s://" + $myhost + ":7042"
$wls_non_ssl = "t3://" + $myhost + ":7041"
$elk_log = "cv_v55_"+ $hostname + ".txt"

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

function check_opera_version {  
  $opera_version=Get-Content D:\MICROS\opera\production\runtimes\opera_pms.ins -TotalCount 1
  $major_version= -join "$opera_version"[0..5]
  if($major_version -eq "5.0.05") {
   Write-Host "Opera : $major_version and script works" -ForegroundColor Yellow
  }else {
    Write-Host "Not an Opera v5_5 and script is intent to work for version : $major_version" -ForegroundColor Red
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

# Prompt secure password
#$securestring = Read-Host -Prompt "Enter weblogic user password" -AsSecureString
#$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securestring)
#$pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
 
#if ($pass -eq ""){
#  Write-Host "weblogic password was not specified. Exiting ..."
#  break
#}

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

  #(Get-Content $sc_path\11g_status.py) -replace 'defaultpassword', "$pass" | Set-Content $sc_path\11g_status.py
  #if ($?) { 
  #  Write-Host("credentials updated successfully!") -ForegroundColor Green
  #}else {
  #  Write-Host("There was a problem updating the credentials in the config.py script, exiting ....")
  #  break
  #}
  (Get-Content $sc_path\11g_status.py) -replace 'myhostname', "$myhost" | Set-Content $sc_path\11g_status.py
  if ($?) { 
     Write-Host("hostname updated successfully!") -ForegroundColor Green
  }else {
    Write-Host("There was a problem updating the credentials in the 11g_status.py script, exiting ....")
    break
  }
  Write-Host ""
}

function prepare_and_execute {
  # delete previous output files to avoid confusion
  Write-Host("Deleting old report files ...")
  #Remove-Item $sc_path\logs\report_v5*.txt | Out-Null
  Remove-Item $sc_path\logs\output_*.ini | Out-Null
  Remove-Item $sc_path\logs\*_status.txt | Out-Null
  #Remove-Item $sc_path\logs\actions_v5*.txt | Out-Null
  #Remove-Item $sc_path\output\transcript_v5*.txt | Out-Null
  write-Host "" 
  New-Item $sc_path\logs\pwd.txt -ItemType File 

  # execute the 11g_status.py jython script and capturing its output into our log
  Write-Host("Executing status validator for $myhost, this will take a minute, or two ...")
  Write-Host ""
  if( Test-Path -LiteralPath $check_admin_server -PathType Leaf ){
    #write-Host "Running : "wlst_check.cmd"" -ForegroundColor Yellow
    Invoke-Expression -command "$sc_path\wlst_check.cmd"
    if ($?) { 
      Write-Host "Executed WLST script in NON-SSL connection" -ForegroundColor Green
    }else {
      (Get-Content $sc_path\11g_status.py) -replace "$wls_non_ssl", "$wls_ssl" | Set-Content $sc_path\11g_status.py
      Invoke-Expression -command "$sc_path\wlst_check.cmd"
      Write-Host "Executed WLST script in SSL connection" -ForegroundColor Green
    }
  }else {
    Write-Host "problem runnig WLST script or not a admin server !! continuing ..." -ForegroundColor Red
    Write-Host ""
  }
  Start-Sleep -s 10
  Write-Host ""
}
function Weblogic_conn_status {
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
      Write-Host "PASS: "$Weblogic_conn_status2[$count].keys" weblogic_conn_status is "$Weblogic_conn_status2[$count].values" on SSL or Non-SSL or Both" -ForegroundColor Yellow
    }else {
      Write-Host "FAIL $hostname "$Weblogic_conn_status2[$count].keys" weblogic_conn_status is "$Weblogic_conn_status2[$count].values" on SSL or Non-SSL or Both" -ForegroundColor Red
    }
    $count -= 1
    }
    Write-Host ""
}
 
function change_status {
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
}

 function server_status {
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
}

function app_status {
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
}
 
function app_deployment {
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
}

function datasource_connection {
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
}

function HTTP_Server_Status {
  Write-Host "[ HTTP_Server_Status ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/server-status"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass = Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL $hostname $Site"  -ForegroundColor Red
  }
  Write-Host ""
 }

function OXI_servlets_status {
 Write-Host "[ OXI_servlets_status ]" -ForegroundColor Green
  Write-Host ""
 [string[]]$sites = ( 
    "https://$myhost/Operajserv/OXIServlets/PMSInterface?info=Y",
    "https://$myhost/Operajserv/OXIServlets/ORSInterface?info=y",
    "https://$myhost/Operajserv/OXIServlets/CRSStatus?info=y",
    "https://$myhost/Operajserv/OXIServlets/ORSLookup?info=y",
    "https://$myhost/Operajserv/OXIServlets/HXInterface?info=y",
    "https://$myhost/Operajserv/OXIServlets/BEInterface?info=Y",
    "https://$myhost/Operajserv/OXIServlets/RemoteMonitor?info=Y",
    "https://$myhost/Operajserv/OXIServlets/HXInterfaceProxy=Y",
    "https://$myhost/Operajserv/OXIServlets/ExportReceiver=Y",
    "https://$myhost/Operajserv/OXIServlets/WebClientProxy?info=Y",
    "https://$myhost/Operajserv/OXIServlets/XMLValidator?info=Y"
 )
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 $pass = Get-Content $sc_path\logs\pwd.txt
 $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
 $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  foreach ($site in $sites)
   {
    try {
    ($Response = Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
    Write-Host "PASS : $Site status code" -ForegroundColor Yellow
    }
    catch {
    Write-Host "FAIL $hostname $Site" -ForegroundColor Red
    }
  }

  [string[]]$sites = ( 
    "https://$myhost/Operajserv/OXIServlets/HXInterfaceProxy=Y",
    "https://$myhost/Operajserv/OXIServlets/ExportReceiver=Y"
 )
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 $pass = Get-Content $sc_path\logs\pwd.txt
 $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
 $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  foreach ($site in $sites)
   {
    try {
    ($Response = Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
    Write-Host "PASS : $Site status code" -ForegroundColor Yellow
    }
    catch {
    Write-Host "WARNING $hostname $Site" -ForegroundColor Cyan
    }
  }
  Write-Host ""
 }

function Report_server_env {
  Write-Host "[ Report_server_env ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/reports/rwservlet/showenv?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass = Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
  if ($status -eq 200)
   {
    write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
   }else{ 
    write-Host  "FAIL $hostname $Site"  -ForegroundColor Red
   }
  Write-Host ""
 }

function Report_server_info {
  Write-Host "[ Report_server_info ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/reports/rwservlet/getserverinfo?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass = Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
  if ($status -eq 200)
   {
    write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
   }else{ 
    write-Host  "FAIL $hostname $Site"  -ForegroundColor Red
  }
  write-Host ""
 }

 function Report_server_jobs {
  Write-Host "[ Report_server_jobs ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/reports/rwservlet/showjobs?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass = Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL $hostname $Site"  -ForegroundColor Red
  }
  Write-Host ""
 }

 function ifc8ws_status {
  Write-Host "[ ifc8ws_status ]" -ForegroundColor Green
  Write-Host ""

  $site = "http://" + $myhost + ":6003/Operajserv/Ifc8ws/Ifc8ws" 
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass = Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL $hostname $Site"  -ForegroundColor Red
  }
   Write-Host ""
 }

 function revert_py {
  # Update jython script "defaultpassword" and "myhostname" strings
 
  Write-Host("revert jython scripts ...")
  Write-Host ""
  (Get-Content $sc_path\11g_status.py) -replace "$wls_ssl", "$wls_non_ssl" | Set-Content $sc_path\11g_status.py
  if ($?) { 
     Write-Host("connection reverted successfully!") -ForegroundColor Green
  }else {
    Write-Host("There was a problem reverting the connection in the 11g_status.py script") -ForegroundColor Red
  }
  (Get-Content $sc_path\11g_status.py) -replace "$myhost", 'myhostname' | Set-Content $sc_path\11g_status.py
  if ($?) { 
     Write-Host("hostname reverted successfully!") -ForegroundColor Green
  }else {
    Write-Host("There was a problem reverting the hostname in the 11g_status.py script") -ForegroundColor Red
  }
  #(Get-Content $sc_path\11g_status.py) -replace "$pass", 'defaultpassword' | Set-Content $sc_path\11g_status.py
  #if ($?) { 
  #   Write-Host("credentials reverted successfully!") -ForegroundColor Green
  #}else {
  #  Write-Host("There was a problem reverting the credentials in the 11g_status.py script") -ForegroundColor Red
  #}
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
     Remove-Item $sc_path\logs\pwd.txt | Out-Null
     Get-Process OpenWith -ErrorAction SilentlyContinue | Stop-Process -PassThru -Force
     exit 1
    } else{
     write-host "All Fine" -ForegroundColor Green
     Write-Output "NO HC ERRORS found for $hostname on $mydate" | Out-File -Encoding ascii $sc_path\logs\$elk_log
     Start-Sleep -s 10
     Move-Item -Path $sc_path\output\*.txt -Destination $sc_path\logs -Force
     Remove-Item $sc_path\logs\pwd.txt | Out-Null
     Get-Process OpenWith -ErrorAction SilentlyContinue | Stop-Process -PassThru -Force
    }
   }catch {
     exit 1
   }
 }

# Function Execution Flow
ps_version_check
check_opera_version
update_py
Start-Transcript $sc_path\output\$transcript -Append | Out-Null
Resource_check
prepare_and_execute
Weblogic_conn_status
change_status
server_status
app_status
app_deployment
datasource_connection
HTTP_Server_Status 
Report_server_env
Report_server_info
Report_server_jobs
ifc8ws_status
OXI_servlets_status
Stop-Transcript | Out-Null
revert_py
script_logger_config
artifactory_upload
check_failure