Import-Module ActiveDirectory

$departements = 'Direction','RH','Finance','IT','Commercial',
                'Marketing','Production','Logistique','Juridique','Support'

Write-Host "`n=== Imbrication AGDLP ===`n" -ForegroundColor Cyan

foreach ($d in $departements) {
    $gg = "GG-$d"
    $dl = "DL-Partage-$d-RW"

    $membres = @(Get-ADGroupMember -Identity $dl -ErrorAction SilentlyContinue |
                 Select-Object -ExpandProperty Name)

    if ($membres -contains $gg) {
        Write-Host "  Deja membre : $gg -> $dl" -ForegroundColor DarkGray
    }
    else {
        Add-ADGroupMember -Identity $dl -Members $gg
        Write-Host "  Ajoute      : $gg -> $dl" -ForegroundColor Green
    }
}

Write-Host "`nTermine.`n" -ForegroundColor Cyan