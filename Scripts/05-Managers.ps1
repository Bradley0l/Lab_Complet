Import-Module ActiveDirectory
$base = 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'

$parService = Get-ADUser -Filter * -SearchBase $base -Properties Department |
              Group-Object Department

foreach ($grp in $parService) {
    $membres = @($grp.Group)
    if ($membres.Count -lt 2) { continue }

    $manager = $membres[0]                       # le 1er devient manager
    $equipe  = $membres | Select-Object -Skip 1  # les autres sous son autorite

    foreach ($u in $equipe) {
        Set-ADUser -Identity $u -Manager $manager.DistinguishedName
    }
    Write-Host ("{0,-12} : {1} manage {2} personnes" -f `
        $grp.Name, $manager.Name, $equipe.Count) -ForegroundColor Green
}