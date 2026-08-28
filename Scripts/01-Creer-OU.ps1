<#
    Cree l'arborescence d'OU du domaine corp.atlas.lab
    Idempotent : peut etre relance sans risque
#>

Import-Module ActiveDirectory

$racine = 'DC=corp,DC=atlas,DC=lab'

function New-AtlasOU {
    param(
        [Parameter(Mandatory)][string] $Nom,
        [Parameter(Mandatory)][string] $Chemin
    )

    $dn = "OU=$Nom,$Chemin"

    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Host "  Existe : $dn" -ForegroundColor DarkGray
    }
    else {
        New-ADOrganizationalUnit -Name $Nom -Path $Chemin `
            -ProtectedFromAccidentalDeletion $true
        Write-Host "  Cree   : $dn" -ForegroundColor Green
    }
}

Write-Host "`n=== Creation de l'arborescence d'OU ===`n" -ForegroundColor Cyan

# --- Niveau 1 ---
New-AtlasOU -Nom 'Atlas' -Chemin $racine
$atlas = "OU=Atlas,$racine"

# --- Niveau 2 ---
'Utilisateurs','Groupes','Postes','Serveurs','ComptesServices','Desactives' |
    ForEach-Object { New-AtlasOU -Nom $_ -Chemin $atlas }

# --- Departements ---
$users = "OU=Utilisateurs,$atlas"
'Direction','RH','Finance','IT','Commercial',
'Marketing','Production','Logistique','Juridique','Support' |
    ForEach-Object { New-AtlasOU -Nom $_ -Chemin $users }

# --- Sous-OU de groupes ---
$groupes = "OU=Groupes,$atlas"
'Global','DomainLocal' |
    ForEach-Object { New-AtlasOU -Nom $_ -Chemin $groupes }

Write-Host "`nTermine.`n" -ForegroundColor Cyan