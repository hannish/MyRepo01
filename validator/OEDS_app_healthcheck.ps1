 # AMS v5.5 health check validator for OEDS

#defining static variables
$sc_path = "D:\scripts\validator"
$mydate = Invoke-Expression -command "Get-Date -Format MM-dd-yyyy_HH-mm"
$myhost = Invoke-Expression -command '(gwmi Win32_NetworkAdapterConfiguration | ? { $_.IPAddress -ne $null }).ipaddress'
$hostname = Invoke-Expression -command "hostname"
$transcript = "transcript_OEDS_" + $hostname + "_" + $mydate + ".txt"
$report= "report_OEDS_"+ $hostname + "_" + $mydate + ".txt"
$myactions = "actions_OEDS_"+ $hostname + "_" + $mydate + ".txt"
$elk_log = "cv_OEDS_"+ $hostname + ".txt"

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

function OEDS_status_check {
    Write-Host "[ OEDS_status ]" -ForegroundColor Green
     Write-Host ""
    [string[]]$sites = (
      #"https://$myhost/OperaADS/OperaAds.aspx",
      #"http://$myhost/HTNG/ActivityService.asmx",
      #"http://$myhost/HTNG2008B/ActivityService.asmx",
      #"http://$myhost/HTNGExt2008B/ActivityExtService.asmx",
      #"http://$myhost/Kiosk30/Opera/KioskInterface.asmx",
      "https://$myhost/OWS_WS_51/Information.asmx",
      "https://$myhost/OWS_WS_51/Availability.asmx",
      "https://$myhost/OWS_WS_51/Reservation.asmx"
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    foreach ($site in $sites)
    {
      try {
       ($Response = Invoke-WebRequest -Uri $site -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing).StatusCode
       Write-Host "PASS : $Site" -ForegroundColor Yellow
       }
       catch {
       Write-Host "FAIL $hostname $Site" -ForegroundColor Red
       }
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
       Get-Content "$sc_path\output\$myactions" | Where-Object { $_ -Match "FAIL"} | Where-Object { $_ -NotMatch "----"} | Where-Object { $_ -NotMatch "Line"} | Out-File -Encoding ascii $sc_path\logs\$elk_log
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
Start-Transcript $sc_path\output\$transcript -Append | Out-Null
OEDS_status_check
Stop-Transcript | Out-Null
script_logger_config
artifactory_upload
check_failure