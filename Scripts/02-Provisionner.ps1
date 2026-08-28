param([switch] $Executer)

Import-Module C:\Scripts\AtlasIAM.psm1 -Force

$ouUsers = 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'
$mdp     = ConvertTo-SecureString 'Atlas!User2026' -AsPlainText -Force
$employes = Import-Csv 'C:\Scripts\employes.csv'

$stats = @{ Cree = 0; MAJ = 0; Simule = 0; Erreur = 0 }
$erreurs = @()

Write-Host "`n=== Provisionnement de $($employes.Count) comptes ===" -ForegroundColor Cyan
if ($Executer) {
    Write-Host 'MODE REEL' -ForegroundColor Red
} else {
    Write-Host 'MODE SIMULATION (-WhatIf)' -ForegroundColor Yellow
}

foreach ($e in $employes) {
    try {
              $r = New-AtlasUser -Matricule $e.Matricule -Prenom $e.Prenom -Nom $e.Nom `
                           -Service $e.Service -OUUtilisateurs $ouUsers `
                           -MotDePasse $mdp -WhatIf:(-not $Executer)

        switch ($r.Action) {
            'Cree'   { $stats.Cree++ }
            'MAJ'    { $stats.MAJ++ }
            'Simule' { $stats.Simule++ }
        }
    }
    catch {
        $stats.Erreur++
        $erreurs += [pscustomobject]@{ Personne = "$($e.Prenom) $($e.Nom)"; Erreur = $_.Exception.Message }
    }
}

Write-Host "`n--- Resultat ---" -ForegroundColor Cyan
$stats.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host ('  {0,-8} : {1}' -f $_.Name, $_.Value)
}

if ($erreurs) {
    Write-Host "`n--- Erreurs ---" -ForegroundColor Red
    $erreurs | Format-Table -AutoSize
    $erreurs | Export-Csv 'C:\Scripts\erreurs-provisionnement.csv' -NoTypeInformation -Encoding UTF8
}