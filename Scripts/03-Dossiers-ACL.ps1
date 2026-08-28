Import-Module C:\Scripts\AtlasIAM.psm1 -Force

$racineHome = 'C:\Homes'
if (-not (Test-Path $racineHome)) { New-Item -Path $racineHome -ItemType Directory | Out-Null }

$sids = Get-AtlasWellKnownSid
$users = Get-ADUser -Filter * -SearchBase 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'

$stats = @{ Cree = 0; Existant = 0 }

foreach ($u in $users) {
    $chemin = Join-Path $racineHome $u.SamAccountName

    if (Test-Path $chemin) { $stats.Existant++; continue }

    New-Item -Path $chemin -ItemType Directory | Out-Null

    # Construire une ACL propre plutot que d'heriter
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)   # coupe l'heritage

    # SYSTEM : controle total (via SID, pas via nom)
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $sids.System, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))

    # Administrateurs : controle total
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $sids.Administrators, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))

    # Le proprietaire : modifier, sur SON dossier uniquement
    $sidUser = New-Object System.Security.Principal.SecurityIdentifier($u.SID)
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $sidUser, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))

    Set-Acl -Path $chemin -AclObject $acl

    # Renseigner l'attribut homeDirectory
    Set-ADUser -Identity $u.SamAccountName -HomeDirectory $chemin -HomeDrive 'H:'

    $stats.Cree++
}

Write-Host "Dossiers crees : $($stats.Cree) | existants : $($stats.Existant)" -ForegroundColor Green