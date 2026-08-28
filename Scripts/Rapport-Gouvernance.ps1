Import-Module ActiveDirectory
$base = 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'
$props = 'Department','Manager','Enabled','LastLogonDate','PasswordLastSet','EmployeeID','whenCreated'

$tous = Get-ADUser -Filter * -SearchBase $base -Properties $props
$actifs = @($tous | Where-Object Enabled)
$inactifs = @(Get-ADUser -Filter * -SearchBase 'OU=Desactives,OU=Atlas,DC=corp,DC=atlas,DC=lab' -ErrorAction SilentlyContinue)

$rapport = [pscustomobject]@{
    'Comptes actifs'        = $actifs.Count
    'Comptes desactives'    = $inactifs.Count
    'Sans matricule'        = @($actifs | Where-Object { -not $_.EmployeeID }).Count
    'Sans manager'          = @($actifs | Where-Object { -not $_.Manager }).Count
    'Sans service'          = @($actifs | Where-Object { -not $_.Department }).Count
    'Dormants > 90j'        = @(Search-ADAccount -AccountInactive -TimeSpan '90.00:00:00' -UsersOnly -SearchBase $base).Count
}

Write-Host "`n=== Rapport de gouvernance IAM — $(Get-Date -Format 'dd/MM/yyyy') ===`n" -ForegroundColor Cyan
$rapport | Format-List

# Export HTML
$style = "<style>body{font-family:Segoe UI}table{border-collapse:collapse}th{background:#1e3a8a;color:#fff;padding:8px}td{border:1px solid #ddd;padding:6px}</style>"
$actifs | Select-Object Name, EmployeeID, Department, @{n='Manager';e={if($_.Manager){($_.Manager -split ',')[0] -replace 'CN='}else{'—'}}} |
    Sort-Object Department |
    ConvertTo-Html -Head $style -PreContent "<h1>Habilitations Atlas</h1>" |
    Out-File 'C:\Scripts\rapport-habilitations.html' -Encoding UTF8

Write-Host "Rapport HTML : C:\Scripts\rapport-habilitations.html" -ForegroundColor Green