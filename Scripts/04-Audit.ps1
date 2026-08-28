$base  = 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'
$props = 'Department','Title','Manager','LastLogonDate','PasswordLastSet',
         'PasswordNeverExpires','Enabled','whenCreated','HomeDirectory'

$tous   = Get-ADUser -Filter * -SearchBase $base -Properties $props
$actifs = @($tous | Where-Object Enabled)

$rapport = [pscustomobject]@{
    'Comptes totaux'         = $tous.Count
    'Comptes actifs'         = $actifs.Count
    'Comptes desactives'     = @($tous | Where-Object { -not $_.Enabled }).Count
    'Mot de passe sans exp.' = @($actifs | Where-Object PasswordNeverExpires).Count
    'Sans dossier personnel' = @($actifs | Where-Object { -not $_.HomeDirectory }).Count
    'Sans manager'           = @($actifs | Where-Object { -not $_.Manager }).Count
    'Crees aujourd hui'      = @($actifs | Where-Object { $_.whenCreated -gt (Get-Date).Date }).Count
}

Write-Host "`n=== Rapport d'audit — $(Get-Date -Format 'dd/MM/yyyy HH:mm') ===`n" -ForegroundColor Cyan
$rapport | Format-List

# Repartition par service, exportee
Get-ADUser -Filter * -SearchBase $base -Properties Department |
    Group-Object Department | Sort-Object Count -Descending |
    Select-Object @{n='Service';e={$_.Name}}, Count |
    Export-Csv 'C:\Scripts\audit-services.csv' -NoTypeInformation -Encoding UTF8

Write-Host "Detail par service exporte : C:\Scripts\audit-services.csv" -ForegroundColor Green