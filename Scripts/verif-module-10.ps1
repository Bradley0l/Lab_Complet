Import-Module ActiveDirectory
$global:ok = $true
function Test-Point($l,$c){$e=if($c){'PASS'}else{'FAIL'};$col=if($c){'Green'}else{'Red'}
    Write-Host ('{0,-50} {1}' -f $l,$e) -ForegroundColor $col; if(-not $c){$global:ok=$false}}

$base = 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'
Write-Host "`n=== Verification Module 10 ===`n" -ForegroundColor Cyan

# Joiner
Test-Point "Joiner E00500 cree et actif" `
    ((Get-ADUser -Filter "EmployeeID -eq 'E00500'" -Properties Enabled).Enabled -eq $true)

# Mover
$mover = Get-ADUser -Filter "EmployeeID -eq 'E00003'" -Properties Department
Test-Point "Mover E00003 a change de service ($($mover.Department))" ($mover.Department -eq 'Commercial')

# Leaver
$leaver = Get-ADUser -Filter "EmployeeID -eq 'E00002'" -Properties Enabled
Test-Point "Leaver E00002 desactive" ($leaver.Enabled -eq $false)
Test-Point "Leaver E00002 en quarantaine" ($leaver.DistinguishedName -like '*OU=Desactives*')

# Fonction et garde-fou
Test-Point "Fonction Sync-AtlasFromSIRH exportee" `
    ($null -ne (Get-Command Sync-AtlasFromSIRH -ErrorAction SilentlyContinue))

# Rapport genere
Test-Point "Rapport HTML genere" (Test-Path 'C:\Scripts\rapport-habilitations.html')

Write-Host ''
if($global:ok){Write-Host 'MODULE 10 VALIDE' -ForegroundColor Green}
else{Write-Host 'Corrige les FAIL' -ForegroundColor Yellow}