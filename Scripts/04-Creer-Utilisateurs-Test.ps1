Import-Module ActiveDirectory

$atlas = 'OU=Atlas,DC=corp,DC=atlas,DC=lab'
$mdp   = ConvertTo-SecureString 'Atlas!Test2026' -AsPlainText -Force

$personnes = @(
    @{ Prenom='Jean';   Nom='Dupont'; Service='Finance' }
    @{ Prenom='Marie';  Nom='Martin'; Service='RH'      }
    @{ Prenom='Karim';  Nom='Bennani'; Service='IT'     }
)

foreach ($p in $personnes) {
    $sam = ('{0}.{1}' -f $p.Prenom.Substring(0,1), $p.Nom).ToLower()
    $ou  = "OU=$($p.Service),OU=Utilisateurs,$atlas"

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Host "  Existe : $sam" -ForegroundColor DarkGray
        continue
    }

    New-ADUser `
        -Name              "$($p.Prenom) $($p.Nom)" `
        -GivenName         $p.Prenom `
        -Surname           $p.Nom `
        -SamAccountName    $sam `
        -UserPrincipalName "$sam@corp.atlas.lab" `
        -Path              $ou `
        -Department        $p.Service `
        -AccountPassword   $mdp `
        -Enabled           $true `
        -ChangePasswordAtLogon $true

    Add-ADGroupMember -Identity "GG-$($p.Service)" -Members $sam
    Write-Host "  Cree   : $sam -> GG-$($p.Service)" -ForegroundColor Green
}