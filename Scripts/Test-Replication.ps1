Import-Module ActiveDirectory

function Test-Point($libelle, $condition) {
    $etat    = if ($condition) { 'OK  ' } else { 'ECHEC' }
    $couleur = if ($condition) { 'Green' } else { 'Red' }
    Write-Host ('{0,-55} {1}' -f $libelle, $etat) -ForegroundColor $couleur
}

Write-Host "`n=== Sante de la replication — $(Get-Date -Format 'dd/MM HH:mm') ===`n" -ForegroundColor Cyan

$meta = Get-ADReplicationPartnerMetadata -Target * -Partition *

foreach ($m in $meta) {
    $sain = ($m.ConsecutiveReplicationFailures -eq 0 -and $m.LastReplicationResult -eq 0)
    $delai = [math]::Round(((Get-Date) - $m.LastReplicationSuccess).TotalMinutes, 0)

    $serveur  = ($m.Server  -split '\.')[0]
    $partenaire = ($m.Partner -split ',')[0] -replace 'CN='
    $partition = ($m.Partition -split ',')[0]

    Test-Point ("{0} <- {1} [{2}] dernier succes il y a {3} min" -f `
        $serveur, $partition, $partenaire, $delai) $sain
}

$echecs = @($meta | Where-Object ConsecutiveReplicationFailures -gt 0)
Write-Host ''
if ($echecs.Count -eq 0) {
    Write-Host 'REPLICATION SAINE — aucun echec en cours' -ForegroundColor Green
} else {
    Write-Host "$($echecs.Count) partenariat(s) en echec" -ForegroundColor Red
}