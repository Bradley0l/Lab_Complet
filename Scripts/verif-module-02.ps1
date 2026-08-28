Import-Module ActiveDirectory
Import-Module GroupPolicy

$global:ok = $true
function Test-Point($libelle, $condition) {
    $etat    = if ($condition) { 'PASS' } else { 'FAIL' }
    $couleur = if ($condition) { 'Green' } else { 'Red' }
    Write-Host ('{0,-52} {1}' -f $libelle, $etat) -ForegroundColor $couleur
    if (-not $condition) { $global:ok = $false }
}

$atlas = 'OU=Atlas,DC=corp,DC=atlas,DC=lab'
Write-Host "`n=== Verification Module 2 ===`n" -ForegroundColor Cyan

# --- Structure ---
$ous = @(Get-ADOrganizationalUnit -Filter * -SearchBase $atlas)
Test-Point "19 OU creees ($($ous.Count))" ($ous.Count -ge 19)

# --- Groupes ---
$gg = @(Get-ADGroup -Filter "Name -like 'GG-*'")
$dl = @(Get-ADGroup -Filter "Name -like 'DL-*'")
Test-Point "10 groupes GG- ($($gg.Count))" ($gg.Count -ge 10)
Test-Point "20 groupes DL- ($($dl.Count))" ($dl.Count -ge 20)

Test-Point "GG- tous en portee Global" `
    (($gg | Where-Object GroupScope -ne 'Global').Count -eq 0)
Test-Point "DL- tous en portee DomainLocal" `
    (($dl | Where-Object GroupScope -ne 'DomainLocal').Count -eq 0)

# --- AGDLP : aucun UTILISATEUR directement dans un groupe DL- ---
$violations = @()
foreach ($g in $dl) {
    $membres = @(Get-ADGroupMember -Identity $g -ErrorAction SilentlyContinue)
    $violations += $membres | Where-Object objectClass -eq 'user'
}
Test-Point "AGDLP respecte : 0 user direct dans DL- ($($violations.Count))" `
    ($violations.Count -eq 0)

Test-Point "GG-Finance membre de DL-Partage-Finance-RW" `
    ((Get-ADGroupMember 'DL-Partage-Finance-RW' | Select-Object -ExpandProperty Name) -contains 'GG-Finance')

# --- Utilisateurs ---
$u = @(Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,$atlas")
Test-Point "3 utilisateurs de test ($($u.Count))" ($u.Count -ge 3)

# --- Redirection des conteneurs ---
$d = Get-ADDomain
Test-Point "redircmp effectue" ($d.ComputersContainer -like "*OU=Postes*")
Test-Point "redirusr effectue" ($d.UsersContainer     -like "*OU=Utilisateurs*")

# --- Delegation ---
$acl = (Get-Acl "AD:OU=Utilisateurs,$atlas").Access
Test-Point "Delegation RL-Support-ResetMdp presente" `
    (($acl | Where-Object { $_.IdentityReference -like '*RL-Support*' }).Count -gt 0)

# --- GPO ---
$gpo = Get-GPO -Name 'ATLAS-Baseline-Postes' -ErrorAction SilentlyContinue
Test-Point "GPO ATLAS-Baseline-Postes existe" ($null -ne $gpo)

$lien = (Get-GPInheritance -Target "OU=Postes,$atlas").GpoLinks
Test-Point "GPO liee sur OU=Postes" `
    (($lien | Where-Object DisplayName -eq 'ATLAS-Baseline-Postes').Count -gt 0)

# --- Client joint ---
$pc = @(Get-ADComputer -Filter * -SearchBase "OU=Postes,$atlas")
Test-Point "Au moins 1 poste dans OU=Postes ($($pc.Count))" ($pc.Count -ge 1)

Write-Host ''
if ($global:ok) { Write-Host 'MODULE 2 VALIDE' -ForegroundColor Green }
else            { Write-Host 'Corrige les FAIL avant le module 3' -ForegroundColor Yellow }