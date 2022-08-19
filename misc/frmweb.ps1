$a = (Get-Process "frmweb" -ErrorAction 0).Count
"FRMWEB RUNNING -> " + $a

$b = (Get-Process "httpd" -ErrorAction 0).Count
"HTTPD RUNNING -> " + $b