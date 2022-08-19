 # AMS v5 health check validator for Opera

 function ps_version_check {
  Write-Host "[ POWERSHELL VERSION CHECK ]" -ForegroundColor Green
  Write-Host ""
  Get-Host | Select-Object Version >> ./logs/ver.txt
  $ps_ver =  Get-Content ./logs/ver.txt -Last 3
  if ($ps_ver -lt "3.0"){
   write-host "$ps_ver" "is higher and script will work"
  }else {
   write-host "$ps_ver" "is lower and script will not work, Please upgrade the PowerShell to 3.0 and above"
   break
  }
  write-host ""
}

# Prompt secure password
$securestring = Read-Host -Prompt "Enter weblogic user password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securestring)
$pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
 
if ($pass -eq $null){
  Write-Host "weblogic password was not specified. Exiting ..."
  break
}

#defining static variables
$mywlst_hc1 = "D:\ORA\MWFR\oracle_common\common\bin\wlst.cmd D:\SRE_tools\status.py"
$mywlst_hc2 = "D:\ORA\MWFR\12cappr2\oracle_common\common\bin\wlst.cmd D:\SRE_tools\status.py"
$mydate = Invoke-Expression -command "Get-Date -Format MM-dd-yyyy_HH-mm"
$myhost = Invoke-Expression -command '[System.Net.Dns]::GetHostByName((hostname)).HostName'
$hostname = hostname
$myshortname = Invoke-Expression -command "hostname"
$mylog = "output_wlst.ini"
$transcript = "transcript_v5_$myshortname_$mydate.txt"
#$report= "report_v5_$myshortname_$mydate.txt"
#$myactions = "actions_v5_$myshortname_$mydate.txt"
#java -showversion 2> ./logs/java_version.txt
#$java_out = cat ./logs/java_version.txt  | Select-String "java : java version"
#$java_ver = $java_ver -replace '(?m)^\s*?\n'
#$wls_ssl = "t3s://" + $myhost + ":7042"
#$wls_non_ssl = "t3://" + $myhost + ":7041"

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

  (Get-Content D:\SRE_tools\status.py) -replace 'defaultpassword', "$pass" | Set-Content D:\SRE_tools\status.py
  if ($?) { 
     Write-Host("credentials updated successfully!") -ForegroundColor Green
  }else {
    Write-Host("There was a problem updating the credentials in the config.py script, exiting ....")
    break
  }
 
  (Get-Content D:\SRE_tools\status.py) -replace 'myhostname', "$myhost" | Set-Content D:\SRE_tools\status.py
  if ($?) { 
     Write-Host("hostname updated successfully!") -ForegroundColor Green
  }else {
    Write-Host("There was a problem updating the credentials in the status.py script, exiting ....")
    break
  }
  Write-Host ""
}

function prepare_and_execute {
  # delete previous output files to avoid confusion
  Write-Host("Deleting old report files ...")
  #Remove-Item ./logs/report_v5*.txt | Out-Null
  Remove-Item ./logs/output_*.ini | Out-Null
  Remove-Item ./logs/*.txt | Out-Null 
  #Remove-Item ./logs/actions_v5*.txt | Out-Null
  #Remove-Item ./output/transcript_v5*.txt | Out-Null
  
  New-Item ./logs/server_status.txt -ItemType File
  New-Item ./logs/app_status.txt -ItemType File
  New-Item ./logs/dep_status.txt -ItemType File
  New-Item ./logs/ds_status.txt -ItemType File
  New-Item ./logs/apache_status.txt -ItemType File
  New-Item ./logs/reportEnv_status.txt -ItemType File
  New-Item ./logs/reportInfo_status.txt -ItemType File
  New-Item ./logs/reportJob_status.txt -ItemType File
  New-Item ./logs/ifc8ws_status.txt -ItemType File
  write-Host "" 

  # execute the status.py jython script and capturing its output into our log
  Write-Host("Executing status validator for $myhost, this will take a minute, or two ...")
  Write-Host ""
  if ($opera_version -eq "5.0.05.00"){
    write-host "$mywlst_hc1" -ForegroundColor Yellow
    Invoke-Expression -command "$mywlst_hc1" | out-null
  }else {
    Write-Host "Opera version is higher" -ForegroundColor Yellow
    write-host "$mywlst_hc2" -ForegroundColor Yellow
    Invoke-Expression -command "$mywlst_hc2" | out-null
    Write-Host ""
  }
 }

 function server_status {
  Write-Host "[ SERVER STATUS CHECK ]" -ForegroundColor Green
  Write-Host ""
 
  # Extract actual values
  # Create array from the input file
  Get-Content D:\SRE_tools\logs\$mylog | Select-String "ServerStatus" -OutVariable server_status | Out-Null
  $server_status | ConvertFrom-StringData -OutVariable server_status2 | Out-Null
 
  $count = $server_status2.count -1
 
  while($count -ge 0){
     $server_status2[$count].keys | Out-Null
     $server_status2[$count].values | Out-Null
 
   if ($server_status2[$count].values -eq "RUNNING"){
      Write-Host "PASS: "$server_status2[$count].keys" server-status is "$server_status2[$count].values"" -ForegroundColor Yellow
      #Write-Host ""$server_status2[$count].values""
      #Write-Host "" 
    }else {
      Write-Host "FAIL: "$server_status2[$count].keys" server-status is "$server_status2[$count].values"" -ForegroundColor Red 
      Write-Output "FAIL: "$server_status2[$count].keys" server-status is "$server_status2[$count].values"" >> ./logs/server_status.txt 
      #Write-Host ""$server_status2[$count].values""
      #Write-Host ""
   }
  $count -= 1
  }
  Select-String -Pattern "FAIL" ./logs/server_status.txt | select line | Out-File ./logs/server1_status.txt
  $val_cnt =  @(Get-Content ./logs/server1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-host "found some WLS server failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-host "ALL WLS servers are fine" -ForegroundColor Yellow
   }
  Write-Host ""
}

function app_status {
  Write-Host "[ APPLICATION STATUS HEALTH CHECK ]" -ForegroundColor Green
  Write-Host ""
 
  # Extract actual values
  # Create array from the input file
  Get-Content D:\SRE_tools\logs\$mylog | Select-String "AppStatus" -OutVariable app_health | Out-Null
  $app_health | ConvertFrom-StringData -OutVariable app_health2 | Out-Null
 
  $count = $app_health.count -1
 
  while($count -ge 0){
     $app_health2[$count].keys | Out-Null
     $app_health2[$count].values | Out-Null
 
   if ($app_health2[$count].values -match "STATE_ACTIVE"){
      Write-Host "PASS: "$app_health2[$count].keys" status is "$app_health2[$count].values"" -ForegroundColor Yellow
      #Write-Host ""$app_health2[$count].values"" 
      #Write-Host ""
    }else {
      Write-Host "FAIL: "$app_health2[$count].keys" status is not "$app_health2[$count].values"" -ForegroundColor Red
      Write-Output "FAIL: "$app_health2[$count].keys" status is not "$app_health2[$count].values"" >> ./logs/app_status.txt
      #Write-Host ""$app_health2[$count].values""  
      #Write-Host ""
   }
  $count -= 1
  }
  Select-String -Pattern "FAIL" ./logs/app_status.txt | select line | Out-File ./logs/app1_status.txt
  $val_cnt =  @(Get-Content ./logs/app1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-host "found some WLS app failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-host "ALL WLS app's are fine" -ForegroundColor Yellow
   }
  Write-Host ""
}
 
function app_deployment {
  Write-Host "[ APPLICATION DEPLOYMENT HEALTH CHECK ]" -ForegroundColor Green
  Write-Host ""
 
  # Extract actual values
  # Create array from the input file
  Get-Content D:\SRE_tools\logs\$mylog | Select-String "AppHealth" -OutVariable deployment_health | Out-Null
  $deployment_health | ConvertFrom-StringData -OutVariable deployment_health2 | Out-Null
 
  $count = $deployment_health2.count -1
 
  while($count -ge 0){
     $deployment_health2[$count].keys | Out-Null
     $deployment_health2[$count].values | Out-Null
 
   if ($deployment_health2[$count].values -match "HEALTH_OK"){
      Write-Host "PASS: "$deployment_health2[$count].keys" status is "$deployment_health2[$count].values"" -ForegroundColor Yellow
      #Write-Host ""$deployment_health2[$count].values"" 
      #Write-Host ""
    }else {
      Write-Host "FAIL: "$deployment_health2[$count].keys" status is not "$deployment_health2[$count].values"" -ForegroundColor Red
      Write-Output "FAIL: "$deployment_health2[$count].keys" status is not "$deployment_health2[$count].values"" >> ./logs/dep_status.txt
      #Write-Host ""$deployment_health2[$count].values"" 
      #Write-Host ""
   }
  $count -= 1
  }
  Select-String -Pattern "FAIL" ./logs/dep_status.txt | select line | Out-File ./logs/dep1_status.txt
  $val_cnt =  @(Get-Content ./logs/dep1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-host "found some WLS deployments failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-host "ALL WLS deployments are fine" -ForegroundColor Yellow
   }
  Write-Host ""
}

function datasource_connection {
  Write-Host "[ DATASOURCE CONNECTION CHECK ]" -ForegroundColor Green
  Write-Host ""
 
  # Extract actual values
  # Create array from the input file
  Get-Content D:\SRE_tools\logs\$mylog | Select-String "TestDatasource" -OutVariable ds_conn | Out-Null
  $ds_conn | ConvertFrom-StringData -OutVariable ds_conn2 | Out-Null
 
  $count = $ds_conn2.count -1
 
  while($count -ge 0){
     $ds_conn2[$count].keys | Out-Null
     $ds_conn2[$count].values | Out-Null
 
   if ($ds_conn2[$count].values -match "OK"){
      Write-Host "PASS: "$ds_conn2[$count].keys" status is "$ds_conn2[$count].values"" -ForegroundColor Yellow
      #Write-Host ""$ds_conn2[$count].values"" 
      #Write-Host ""
    }else {
      Write-Host "FAIL: "$ds_conn2[$count].keys" status is not "$ds_conn2[$count].values"" -ForegroundColor Red
      #Write-Output "FAIL: "$ds_conn2[$count].keys" status is not "$ds_conn2[$count].values"" >> ./logs/ds_status.txt
      #Write-Host ""$ds_conn2[$count].values""  
      #Write-Host ""
   }
  $count -= 1
  }
  Select-String -Pattern "FAIL" ./logs/ds_status.txt | select line | Out-File ./logs/ds1_status.txt
  $val_cnt =  @(Get-Content ./logs/ds1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-host "found some WLS datasource failed, please check and continue the patch process" -ForegroundColor Red
   pause
  }else {
   write-host "ALL WLS datasources are fine" -ForegroundColor Yellow
   }
  Write-Host ""
}

function HTTP_Server_Status {
  Write-Host "[ HTTP_Server_Status ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/server-status"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $securepassword = ConvertTo-SecureString "opera321" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
   write-Output  "FAIL : $Site status code $status"  >> ./logs/apache_status.txt
  }
  Select-String -Pattern "FAIL" ./logs/apache_status.txt | select line | Out-File ./logs/apache1_status.txt
  $val_cnt =  @(Get-Content ./logs/apache1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-Host "found HTTP server failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-Host "HTTP servers are fine" -ForegroundColor Yellow
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
 $securepassword = ConvertTo-SecureString “Password” -AsPlainText -Force
 $credentials = New-Object System.Management.Automation.PSCredential(“Username”, $securepassword)
  foreach ($site in $sites)
   {
    try {
    ($Response = Invoke-WebRequest -Uri $site -Credential $credentials).StatusCode
    Write-Host "PASS : $Site status code" -ForegroundColor Yellow
    Write-Output "PASS : $Site status code" -ForegroundColor Yellow >> ./logs/oxi_status.txt
    }
    catch {
    Write-Host "FAIL : $Site status code” -ForegroundColor Red
    }
  }
  Select-String -Pattern "PASS" ./logs/oxi_status.txt | select line | Out-File ./logs/oxi1_status.txt
  $val_cnt =  @(Get-Content ./logs/oxi1_status.txt).Length
  if ($val_cnt -eq "0"){
   write-host "found OXI server failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-Host "OXI servers are fine" -ForegroundColor Yellow
   }
  Write-Host ""
 }

function Report_server_env {
  Write-Host "[ Report_server_env ]" -ForegroundColor Green
  Write-Host ""


  $site = "https://$myhost/reports/rwservlet/showenv?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $securepassword = ConvertTo-SecureString "opera321" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
   write-Output  "FAIL : $Site status code $status"  -ForegroundColor Red >> ./logs/reportEnv_status.txt
  }
  Select-String -Pattern "FAIL" ./logs/reportEnv_status.txt | select line | Out-File ./logs/reportEnv1_status.txt
  $val_cnt =  @(Get-Content ./logs/reportEnv1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-host "found ReportEnv server failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-host "ReportEnv servers are fine" -ForegroundColor Yellow
   }
  Write-Host ""
 }

function Report_server_info {
  Write-Host "[ Report_server_info ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/reports/rwservlet/getserverinfo?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $securepassword = ConvertTo-SecureString "opera321" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
   write-Output  "FAIL : $Site status code $status"  -ForegroundColor Red >> ./logs/reportInfo_status.txt
  }
  Select-String -Pattern "FAIL" ./logs/reportInfo_status.txt | select line | Out-File ./logs/reportInfo1_status.txt
  $val_cnt =  @(Get-Content ./logs/reportInfo1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-Host "found ReportInfo server failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-Host "ReportInfo servers are fine" -ForegroundColor Yellow
   }
  write-Host ""
 }

 function Report_server_jobs {
  Write-Host "[ Report_server_jobs ]" -ForegroundColor Green
  Write-Host ""

  $site = "https://$myhost/reports/rwservlet/showjobs?server=rep" + $hostname + "OPERA"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $securepassword = ConvertTo-SecureString "opera321" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
   write-Output  "FAIL : $Site status code $status"  -ForegroundColor Red >> ./logs/reportJob_status.txt
  }
  Select-String -Pattern "FAIL" ./logs/reportJob_status.txt | select line | Out-File ./logs/reportJob1_status.txt
  $val_cnt =  @(Get-Content ./logs/reportJob1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-Host "found ReportJob server failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-Host "ReportJob servers are fine " -ForegroundColor Yellow
   }
  Write-Host ""
 }

 function ifc8ws_status {
  Write-Host "[ ifc8ws_status ]" -ForegroundColor Green
  Write-Host ""

  $site = "http://" + $myhost + ":6003/Operajserv/Ifc8ws/Ifc8ws" 
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $securepassword = ConvertTo-SecureString "opera321" -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential("weblogic", $securepassword)
  $status = (Invoke-WebRequest -Uri $site -Credential $credentials).StatusCode
  if ($status -eq 200)
  {
   write-Host  "PASS : $Site status code $status" -ForegroundColor Yellow
  }else{ 
   write-Host  "FAIL : $Site status code $status"  -ForegroundColor Red
   write-Output  "FAIL : $Site status code $status"  -ForegroundColor Red >> ./logs/ifc8ws_status.txt
  }
  Select-String -Pattern "FAIL" ./logs/ifc8ws_status.txt | select line | Out-File ./logs/ifc8ws1_status.txt
  $val_cnt =  @(Get-Content ./logs/ifc8ws1_status.txt).Length
  if ($val_cnt -ne "0"){
   write-host "found ifc8ws service failed, please check and continue the patch process" -ForegroundColor Red
   pause 
  }else {
   write-host "ifc8ws service are fine " -ForegroundColor Yellow
   }
  Write-Host ""
 }

 function revert_py {
  # Update jython script "defaultpassword" and "myhostname" strings
 
  Write-Host("revert jython scripts ...")
  Write-Host ""

  (Get-Content D:\SRE_tools\status.py) -replace "$wls_non_ssl", "$wls_ssl" | Set-Content D:\SRE_tools\status.py
  if ($?) { 
    Write-Host("wls conn reverted successfully!") -ForegroundColor Green
  }else {
   Write-Host("There was a problem reverting the wls conn in the status.py script, exiting ....")
   break
  }
  (Get-Content D:\SRE_tools\status.py) -replace "$myhost", 'myhostname' | Set-Content D:\SRE_tools\status.py
  if ($?) { 
     Write-Host("hostname reverted successfully!") -ForegroundColor Green
  }else {
    Write-Host("There was a problem reverting the hostname in the status.py script, exiting ....")
    break
  }
  Write-Host ""
}

# Function Execution Flow
ps_version_check
update_py
prepare_and_execute
Start-Transcript ./output/$transcript -Append | Out-Null
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
