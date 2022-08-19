  # AMS v5.5 health check validator for Opera

#defining static variables
$sc_path = "D:\scripts\validator"
$myhost = Invoke-Expression -command '[System.Net.Dns]::GetHostByName((hostname)).HostName'
$hostname = Invoke-Expression -command "hostname"
$mylog = "output_wlst.ini"
$wls_ssl = "t3s://" + $myhost + ":7042"
$wls_non_ssl = "t3://" + $myhost + ":7041"
$check_admin_server = "D:\ORA\user_projects\domains\OperaDomain\servers\AdminServer\data\nodemanager\AdminServer.state"

 function ps_version_check {
  Write-Host "[ POWERSHELL VERSION CHECK ]" -ForegroundColor Green
  Write-Host ""
  Get-Host | Select-Object Version >> $sc_path\logs\ver.txt
  $ps_ver =  Get-Content $sc_path\logs\ver.txt -Last 3
  if ($ps_ver -lt "3.0"){
   write-host "$ps_ver" "is higher and script will work"
  }else {
   write-host "$ps_ver" "is lower and script will not work, Please upgrade the PowerShell to 3.0 and above"
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
 
if ($pass -eq ""){
  Write-Host "weblogic password was not specified. Exiting ..."
  break
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
  
$opera_version=Get-Content D:\MICROS\opera\production\runtimes\opera_pms.ins -TotalCount 1
Write-Host "Opera V5 version is $opera_version" -ForegroundColor Yellow
Write-Host ""

function update_py {
  # Update jython script "defaultpassword" and "myhostname" strings
 
  Write-Host("Updating jython scripts ...")
  Write-Host ""

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
  Remove-Item $sc_path\logs\output_*.ini | Out-Null
  Remove-Item $sc_path\logs\*_status.txt | Out-Null
  write-Host "" 
  New-Item $sc_path\logs\pwd.txt -ItemType File 

  # execute the 11g_status.py jython script and capturing its output into our log
  Write-Host("Executing status validator for $myhost, this will take a minute, or two ...")
  Write-Host ""
  if(Test-Path -LiteralPath $check_admin_server -PathType Leaf ){
    write-Host "Trying : wlst_check.cmd with NON-SSL connection" -ForegroundColor Yellow
    Invoke-Expression -command "$sc_path\wlst_check.cmd" 
    if ($?) { 
      Write-Host("wlst_check.cmd with NON-SSL connection ran successfully!") -ForegroundColor Green
    }else {
      write-Host "Trying : wlst_check.cmd with SSL connection" -ForegroundColor Yellow
      (Get-Content $sc_path\11g_status.py) -replace "$wls_non_ssl", "$wls_ssl" | Set-Content $sc_path\11g_status.py
      Invoke-Expression -command "$sc_path\wlst_check.cmd"
    }
  }else {
    Write-Host "problem runnig WLST script or not an admin server, continuing ..." -ForegroundColor Red
    Write-Host ""
  }
  Start-Sleep -s 10
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
      Write-Host "FAIL: "$change_status2[$count].keys" change-status is "$change_status2[$count].values"" -ForegroundColor Red
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
      Write-Host "FAIL: "$server_status2[$count].keys" server-status is "$server_status2[$count].values"" -ForegroundColor Red 
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
      Write-Host "FAIL: "$app_health2[$count].keys" status is not "$app_health2[$count].values"" -ForegroundColor Red
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
      Write-Host "FAIL: "$deployment_health2[$count].keys" status is not "$deployment_health2[$count].values"" -ForegroundColor Red
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
      Write-Host "FAIL: "$ds_conn2[$count].keys" status is not "$ds_conn2[$count].values"" -ForegroundColor Red
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
  $pass=Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
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
  $pass=Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  foreach ($site in $sites)
   {
    try {
    ($Response = Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30).StatusCode
    Write-Host "PASS : $Site status code" -ForegroundColor Yellow
    }
    catch {
    Write-Host "FAIL : $Site status code" -ForegroundColor Red
    }
  }
  Write-Host ""
 }

function Report_server_env {
  Write-Host "[ Report_server_env ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/reports/rwservlet/showenv?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass=Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30).StatusCode
  if ($status -eq 200)
   {
    write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
   }else{ 
    write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
   }
  Write-Host ""
 }

function Report_server_info {
  Write-Host "[ Report_server_info ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/reports/rwservlet/getserverinfo?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass=Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30).StatusCode
  if ($status -eq 200)
   {
    write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
   }else{ 
    write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
  }
  write-Host ""
 }

 function Report_server_jobs {
  Write-Host "[ Report_server_jobs ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/reports/rwservlet/showjobs?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass=Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
  }
  Write-Host ""
 }

 function ifc8ws_status {
  Write-Host "[ ifc8ws_status ]" -ForegroundColor Green
  Write-Host ""

  $site = "http://" + $myhost + ":6003/Operajserv/Ifc8ws/Ifc8ws" 
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $pass=Get-Content $sc_path\logs\pwd.txt
  $securepassword = ConvertTo-SecureString "$pass" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials -MaximumRedirection 5 -TimeoutSec 30).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
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
  Write-Host ""
}

# Function Execution Flow
ps_version_check
update_py
Resource_check
prepare_and_execute
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
revert_py