Import-Module ActiveDirectory
$global:ok = $true
function Test-Point($l,$c){$e=if($c){'PASS'}else{'FAIL'};$col=if($c){'Green'}else{'Red'}
    Write-Host ('{0,-50} {1}' -f $l,$e) -ForegroundColor $col; if(-not $c){$global:ok=$false}}

Write-Host "`n=== Verification Module 6 ===`n" -ForegroundColor Cyan

# Aucun Domain Admin avec SPN (Kerberoastable + privilegie = interdit)
$daSpn = @(Get-ADGroupMember 'Domain Admins' -Recursive | Get-ADUser -Properties ServicePrincipalName |
           Where-Object ServicePrincipalName)
Test-Point "Aucun Domain Admin Kerberoastable ($($daSpn.Count))" ($daSpn.Count -eq 0)

# Aucun compte AS-REP roastable
$asrep = @(Get-ADUser -Filter "DoesNotRequirePreAuth -eq 'True'")
Test-Point "Aucun compte AS-REP roastable ($($asrep.Count))" ($asrep.Count -eq 0)

# LAPS deploye
Test-Point "GPO LAPS existe" ($null -ne (Get-GPO -Name 'ATLAS-LAPS' -ErrorAction SilentlyContinue))

# gMSA cree
Test-Point "gMSA gmsa-sql existe" ($null -ne (Get-ADServiceAccount -Identity 'gmsa-sql' -ErrorAction SilentlyContinue))

# Protected Users utilise
Test-Point "Protected Users a des membres" (@(Get-ADGroupMember 'Protected Users').Count -gt 0)

# Politique de mot de passe >= 14
$pp = Get-ADDefaultDomainPasswordPolicy
Test-Point "Longueur mini mot de passe >= 14 ($($pp.MinPasswordLength))" ($pp.MinPasswordLength -ge 14)

# Spooler desactive sur le DC
Test-Point "Print Spooler desactive" ((Get-Service Spooler).StartType -eq 'Disabled')

Write-Host ''
if($global:ok){Write-Host 'MODULE 6 VALIDE' -ForegroundColor Green}
else{Write-Host 'Corrige les FAIL' -ForegroundColor Yellow}