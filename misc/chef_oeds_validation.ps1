 # AMS v5.5 health check validator for OEDS

#defining static variables
$sc_path = "D:\scripts\validator"
$myhost = Invoke-Expression -command '(gwmi Win32_NetworkAdapterConfiguration | ? { $_.IPAddress -ne $null }).ipaddress'
#$hostname = Invoke-Expression -command "hostname"

function ps_version_check {
    Write-Host "[ POWERSHELL VERSION CHECK ]" -ForegroundColor Green
    Write-Host ""
    Get-Host | Select-Object Version >> $sc_path\logs\ver.txt
    $ps_ver =  Get-Content $sc_path\logs\ver.txt -Last 3
    if ($ps_ver -lt "3.0"){
     write-host "$ps_ver" "is higher and script will work"
    }else {
     write-host "$ps_ver" "is lower and script will not work, Please upgrade the PowerShell to 4.0 and above"
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
      "http://$myhost/OWS_WS_51/Information.asmx",
      "http://$myhost/OWS_WS_51/Availability.asmx",
      "http://$myhost/OWS_WS_51/Reservation.asmx"
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    foreach ($site in $sites)
    {
      try {
       ($Response = Invoke-WebRequest -Uri $site -MaximumRedirection 5 -TimeoutSec 30).StatusCode
       Write-Host "PASS : $Site" -ForegroundColor Yellow
       }
       catch {
       Write-Host "FAIL : $Site" -ForegroundColor Red
       }
     }
     Write-Host ""
  }

# Function Execution Flow
ps_version_check
OEDS_status_check