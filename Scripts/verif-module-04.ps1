Import-Module ActiveDirectory
$global:ok = $true
function Test-Point($libelle, $condition) {
    $etat    = if ($condition) { 'PASS' } else { 'FAIL' }
    $couleur = if ($condition) { 'Green' } else { 'Red' }
    Write-Host ('{0,-50} {1}' -f $libelle, $etat) -ForegroundColor $couleur
    if (-not $condition) { $global:ok = $false }
}

Write-Host "`n=== Verification Module 4 ===`n" -ForegroundColor Cyan

$dcs = @(Get-ADDomainController -Filter *)
Test-Point "2 controleurs de domaine ($($dcs.Count))" ($dcs.Count -ge 2)
Test-Point "DC01 present" (($dcs.Name) -contains 'DC01')
Test-Point "DC02 present" (($dcs.Name) -contains 'DC02')
Test-Point "DC02 est catalogue global" `
    (($dcs | Where-Object Name -eq 'DC02').IsGlobalCatalog)

# Replication sans echec
$repl = repadmin /showrepl DC02 /csv | ConvertFrom-Csv
$echecs = @($repl | Where-Object { [int]$_.'Number of Failures' -gt 0 })
Test-Point "Replication DC02 sans echec ($($echecs.Count))" ($echecs.Count -eq 0)

# Les 5 roles FSMO sont attribues
$d = Get-ADDomain; $f = Get-ADForest
Test-Point "PDC Emulator attribue"      ($null -ne $d.PDCEmulator)
Test-Point "RID Master attribue"        ($null -ne $d.RIDMaster)
Test-Point "Schema Master attribue"     ($null -ne $f.SchemaMaster)

# Corbeille AD active
$rb = Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'"
Test-Point "Corbeille AD activee" ($rb.EnabledScopes.Count -gt 0)

# Sauvegarde presente
$bk = wbadmin get versions 2>$null | Select-String 'Version'
Test-Point "Au moins une sauvegarde System State" ($null -ne $bk)

Write-Host ''
if ($global:ok) { Write-Host 'MODULE 4 VALIDE' -ForegroundColor Green }
else            { Write-Host 'Corrige les FAIL' -ForegroundColor Yellow }