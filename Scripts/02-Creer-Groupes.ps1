Import-Module ActiveDirectory

$atlas   = 'OU=Atlas,DC=corp,DC=atlas,DC=lab'
$ouGG    = "OU=Global,OU=Groupes,$atlas"
$ouDL    = "OU=DomainLocal,OU=Groupes,$atlas"

$departements = 'Direction','RH','Finance','IT','Commercial',
                'Marketing','Production','Logistique','Juridique','Support'

function New-AtlasGroupe {
    param(
        [Parameter(Mandatory)][string] $Nom,
        [Parameter(Mandatory)][string] $Chemin,
        [Parameter(Mandatory)][ValidateSet('Global','DomainLocal')][string] $Portee,
        [string] $Description = ''
    )

    if (Get-ADGroup -Filter "Name -eq '$Nom'" -ErrorAction SilentlyContinue) {
        Write-Host "  Existe : $Nom" -ForegroundColor DarkGray
    }
    else {
        New-ADGroup -Name $Nom -Path $Chemin -GroupScope $Portee `
                    -GroupCategory Security -Description $Description
        Write-Host "  Cree   : $Nom" -ForegroundColor Green
    }
}

Write-Host "`n=== Groupes globaux (fonctions) ===`n" -ForegroundColor Cyan
foreach ($d in $departements) {
    New-AtlasGroupe -Nom "GG-$d" -Chemin $ouGG -Portee Global `
                    -Description "Tous les collaborateurs du service $d"
}

Write-Host "`n=== Groupes domaine local (ressources) ===`n" -ForegroundColor Cyan
foreach ($d in $departements) {
    New-AtlasGroupe -Nom "DL-Partage-$d-RW" -Chemin $ouDL -Portee DomainLocal `
                    -Description "Lecture/ecriture sur le partage $d"
    New-AtlasGroupe -Nom "DL-Partage-$d-RO" -Chemin $ouDL -Portee DomainLocal `
                    -Description "Lecture seule sur le partage $d"
}

Write-Host "`nTermine.`n" -ForegroundColor Cyan