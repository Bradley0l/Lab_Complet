Import-Module ActiveDirectory
$base = 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'
$props = 'Enabled','Department','Manager','EmployeeID','LastLogonDate',
         'PasswordLastSet','PasswordNeverExpires','ServicePrincipalName','AdminCount'

$u = Get-ADUser -Filter * -SearchBase $base -Properties $props
$actifs = @($u | Where-Object Enabled)

Write-Host "`n===== AUDIT FINAL — corp.atlas.lab — $(Get-Date -Format 'dd/MM/yyyy') =====`n" -ForegroundColor Cyan

# --- Population ---
Write-Host "[ POPULATION ]" -ForegroundColor Yellow
"  Comptes actifs        : $($actifs.Count)"
"  Comptes desactives    : $(@($u | Where-Object {-not $_.Enabled}).Count)"
"  Sans matricule        : $(@($actifs | Where-Object {-not $_.EmployeeID}).Count)"
"  Sans service          : $(@($actifs | Where-Object {-not $_.Department}).Count)"

# --- Securite des comptes ---
Write-Host "`n[ SECURITE ]" -ForegroundColor Yellow
"  Mot de passe sans exp.: $(@($actifs | Where-Object PasswordNeverExpires).Count)"
"  Comptes Kerberoastables: $(@($actifs | Where-Object ServicePrincipalName).Count)"
"  AdminCount = 1         : $(@($actifs | Where-Object {$_.AdminCount -eq 1}).Count)"
$daSpn = @(Get-ADGroupMember 'Domain Admins' -Recursive | Get-ADUser -Properties ServicePrincipalName | Where-Object ServicePrincipalName)
"  Domain Admins avec SPN : $($daSpn.Count)   (DOIT etre 0)"

# --- Comptes a privileges ---
Write-Host "`n[ PRIVILEGES ]" -ForegroundColor Yellow
"  Domain Admins         : $(@(Get-ADGroupMember 'Domain Admins').Count)"
"  Enterprise Admins     : $(@(Get-ADGroupMember 'Enterprise Admins').Count)"
"  Protected Users       : $(@(Get-ADGroupMember 'Protected Users').Count)"

# --- Infrastructure ---
Write-Host "`n[ INFRASTRUCTURE ]" -ForegroundColor Yellow
"  Controleurs de domaine: $(@(Get-ADDomainController -Filter *).Count)"
"  gMSA                  : $(@(Get-ADServiceAccount -Filter *).Count)"
"  Corbeille AD active   : $(if((Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'").EnabledScopes){'Oui'}else{'Non'})"

# --- Hygiene ---
Write-Host "`n[ HYGIENE ]" -ForegroundColor Yellow
"  Dormants > 90j        : $(@(Search-ADAccount -AccountInactive -TimeSpan '90.00:00:00' -UsersOnly -SearchBase $base).Count)"
"  Sans manager          : $(@($actifs | Where-Object {-not $_.Manager}).Count)   (les responsables, normal)"

Write-Host "`n=====================================================`n" -ForegroundColor Cyan