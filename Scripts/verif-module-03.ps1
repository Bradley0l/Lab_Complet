Import-Module ActiveDirectory
$global:ok = $true
function Test-Point($libelle, $condition) {
    $etat    = if ($condition) { 'PASS' } else { 'FAIL' }
    $couleur = if ($condition) { 'Green' } else { 'Red' }
    Write-Host ('{0,-50} {1}' -f $libelle, $etat) -ForegroundColor $couleur
    if (-not $condition) { $global:ok = $false }
}

$base = 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'
Write-Host "`n=== Verification Module 3 ===`n" -ForegroundColor Cyan

Test-Point "Module AtlasIAM importable" `
    ($null -ne (Get-Module -ListAvailable -Name AtlasIAM -ErrorAction SilentlyContinue) -or (Test-Path 'C:\Scripts\AtlasIAM.psm1'))

$users = @(Get-ADUser -Filter * -SearchBase $base)
Test-Point "Au moins 500 comptes ($($users.Count))" ($users.Count -ge 500)

$upns = (Get-ADUser -Filter * -SearchBase $base -Properties UserPrincipalName).UserPrincipalName
Test-Point "Tous les UPN sont uniques" (($upns | Group-Object | Where-Object Count -gt 1).Count -eq 0)

$sansService = @(Get-ADUser -Filter * -SearchBase $base -Properties Department |
                 Where-Object { -not $_.Department })
Test-Point "Tous ont un service ($($sansService.Count) sans)" ($sansService.Count -eq 0)

$homes = @(Get-ChildItem 'C:\Homes' -Directory -ErrorAction SilentlyContinue)
Test-Point "Au moins 500 dossiers personnels ($($homes.Count))" ($homes.Count -ge 500)

# ACL : heritage coupe sur un dossier reel
$sam = ($users | Select-Object -First 1).SamAccountName
$acl = Get-Acl "C:\Homes\$sam" -ErrorAction SilentlyContinue
Test-Point "Heritage coupe sur les dossiers" ($acl.AreAccessRulesProtected)

Test-Point "CSV d'audit genere" (Test-Path 'C:\Scripts\audit-services.csv')

Write-Host ''
if ($global:ok) { Write-Host 'MODULE 3 VALIDE' -ForegroundColor Green }
else            { Write-Host 'Corrige les FAIL' -ForegroundColor Yellow }