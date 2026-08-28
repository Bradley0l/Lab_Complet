<#
    Module AtlasIAM — fonctions de provisionnement pour corp.atlas.lab
    Import : Import-Module C:\Scripts\AtlasIAM.psm1 -Force
#>

# --- Cache des SID bien connus (resolution independante de la langue) ---
$script:AtlasSidCache = $null

function Get-AtlasWellKnownSid {
    <#
        Retourne les SID des groupes integres, resolus depuis le SID du domaine.
        Ne JAMAIS ecrire les noms en dur : ils sont traduits selon la langue du serveur.
    #>
    if (-not $script:AtlasSidCache) {
        $domainSid = (Get-ADDomain).DomainSID.Value
        $script:AtlasSidCache = @{
            System           = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
            Administrators   = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
            DomainAdmins     = [Security.Principal.SecurityIdentifier]::new("$domainSid-512")
            DomainUsers      = [Security.Principal.SecurityIdentifier]::new("$domainSid-513")
            EnterpriseAdmins = [Security.Principal.SecurityIdentifier]::new("$domainSid-519")
        }
    }
    return $script:AtlasSidCache
}

function Get-AtlasUniqueUpn {
    <# Trouve un UPN libre dans la foret en ajoutant un suffixe numerique #>
    param(
        [Parameter(Mandatory)][string] $Base,
        [Parameter(Mandatory)][string] $Suffixe
    )
    $candidat = "$Base@$Suffixe"; $i = 1
    while (Get-ADUser -Filter "UserPrincipalName -eq '$candidat'" -ErrorAction SilentlyContinue) {
        $i++; $candidat = "$Base$i@$Suffixe"
    }
    return $candidat
}

function Get-AtlasUniqueCn {
    <# Trouve un CN libre dans un conteneur donne #>
    param(
        [Parameter(Mandatory)][string] $Base,
        [Parameter(Mandatory)][string] $Chemin
    )
    $candidat = $Base; $i = 1
    while (Get-ADObject -Filter "Name -eq '$candidat'" -SearchBase $Chemin `
                        -SearchScope OneLevel -ErrorAction SilentlyContinue) {
        $i++; $candidat = "$Base ($i)"
    }
    return $candidat
}

function Disable-AtlasUser {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $SamAccountName)

    $u = Get-ADUser -Identity $SamAccountName -Properties MemberOf, PrimaryGroup
    if ($PSCmdlet.ShouldProcess($SamAccountName, 'Desactiver')) {

        Disable-ADAccount -Identity $u

        # Changer le mot de passe invalide les sessions en cours
        Set-ADAccountPassword -Identity $u -Reset `
            -NewPassword (ConvertTo-SecureString (New-Guid).Guid -AsPlainText -Force)

        # Retirer de tous les groupes sauf le principal (Domain Users)
        foreach ($g in $u.MemberOf) {
            Remove-ADGroupMember -Identity $g -Members $u -Confirm:$false -ErrorAction SilentlyContinue
        }

        Move-ADObject -Identity $u.DistinguishedName `
            -TargetPath 'OU=Desactives,OU=Atlas,DC=corp,DC=atlas,DC=lab'
    }
}

function Get-AtlasUniqueSam {
    param([Parameter(Mandatory)][string] $Base)
    $b = ($Base.ToLower() -replace '[^a-z0-9.]','')
    if ($b.Length -gt 16) { $b = $b.Substring(0,16) }
    $candidat = $b; $i = 1
    while (Get-ADUser -Filter "SamAccountName -eq '$candidat'" -ErrorAction SilentlyContinue) {
        $i++; $candidat = "$b$i"
    }
    return $candidat
}

function Invoke-AtlasOffboarding {
    param([Parameter(Mandatory)][string[]] $Matricules)

    $base  = 'OU=Utilisateurs,OU=Atlas,DC=corp,DC=atlas,DC=lab'
    $total = (Get-ADUser -Filter * -SearchBase $base).Count
    $ratio = $Matricules.Count / $total

    if ($ratio -gt 0.10) {
        throw ("GARDE-FOU : {0} desactivations sur {1} ({2:P0}). " -f `
               $Matricules.Count, $total, $ratio) +
              "Verifiez l'export RH avant de continuer."
    }

    foreach ($m in $Matricules) {
        $u = Get-ADUser -Filter "EmployeeID -eq '$m'" -ErrorAction SilentlyContinue
        if ($u) { Disable-AtlasUser -SamAccountName $u.SamAccountName }
    }
}

function Sync-AtlasFromSIRH {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $CheminCSV,
        [Parameter(Mandatory)][string] $OUUtilisateurs,
        [Parameter(Mandatory)][securestring] $MotDePasseInitial
    )

    $lignes = Import-Csv $CheminCSV
    $rapport = @{ Joiner=0; Mover=0; Leaver=0; Inchange=0; Erreur=0 }
    $details = @()

    # --- GARDE-FOU : refuser un traitement de masse anormal ---
    $totalActuel = (Get-ADUser -Filter * -SearchBase $OUUtilisateurs).Count
    $aPartir = @($lignes | Where-Object Statut -eq 'Parti').Count
    if ($totalActuel -gt 0 -and ($aPartir / $totalActuel) -gt 0.10) {
        throw ("GARDE-FOU : {0} departs sur {1} comptes ({2:P0}). " -f `
               $aPartir, $totalActuel, ($aPartir/$totalActuel)) +
              "Verifiez l'export SIRH avant de continuer."
    }

    foreach ($l in $lignes) {
        try {
            $existant = Get-ADUser -Filter "EmployeeID -eq '$($l.Matricule)'" -Properties Department, MemberOf -ErrorAction SilentlyContinue

            # --- LEAVER ---
            if ($l.Statut -eq 'Parti') {
                if ($existant) {
                    if ($PSCmdlet.ShouldProcess($l.Matricule, 'Desactiver (Leaver)')) {
                        Disable-ADAccount -Identity $existant
                        Set-ADAccountPassword -Identity $existant -Reset `
                            -NewPassword (ConvertTo-SecureString (New-Guid).Guid -AsPlainText -Force)
                        Get-ADPrincipalGroupMembership -Identity $existant |
                            Where-Object Name -ne 'Domain Users' |
                            ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $existant -Confirm:$false -ErrorAction SilentlyContinue }
                        Move-ADObject -Identity $existant.DistinguishedName `
                            -TargetPath "OU=Desactives,OU=Atlas,DC=corp,DC=atlas,DC=lab"
                    }
                    $rapport.Leaver++; $details += "LEAVER  : $($l.Prenom) $($l.Nom)"
                }
                continue
            }

            # --- JOINER ---
            if (-not $existant) {
                if ($PSCmdlet.ShouldProcess($l.Matricule, 'Creer (Joiner)')) {
                    New-AtlasUser -Matricule $l.Matricule -Prenom $l.Prenom -Nom $l.Nom `
                        -Service $l.Service -OUUtilisateurs $OUUtilisateurs -MotDePasse $MotDePasseInitial
                }
                $rapport.Joiner++; $details += "JOINER  : $($l.Prenom) $($l.Nom) -> $($l.Service)"
                continue
            }

            # --- MOVER (le service a change) ---
            if ($existant.Department -ne $l.Service) {
                if ($PSCmdlet.ShouldProcess($l.Matricule, "Mover $($existant.Department) -> $($l.Service)")) {
                    # RETIRER d'abord l'ancien groupe
                    Remove-ADGroupMember -Identity "GG-$($existant.Department)" -Members $existant -Confirm:$false -ErrorAction SilentlyContinue
                    # AJOUTER le nouveau
                    Add-ADGroupMember -Identity "GG-$($l.Service)" -Members $existant -ErrorAction SilentlyContinue
                    Set-ADUser -Identity $existant -Department $l.Service
                    Move-ADObject -Identity $existant.DistinguishedName `
                        -TargetPath "OU=$($l.Service),$OUUtilisateurs" -ErrorAction SilentlyContinue
                }
                $rapport.Mover++; $details += "MOVER   : $($l.Prenom) $($l.Nom) : $($existant.Department) -> $($l.Service)"
                continue
            }

            $rapport.Inchange++
        }
        catch {
            $rapport.Erreur++; $details += "ERREUR  : $($l.Matricule) - $($_.Exception.Message)"
        }
    }

    # Rapport
    Write-Host "`n=== Synchronisation SIRH ===" -ForegroundColor Cyan
    $rapport.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host ("  {0,-10} : {1}" -f $_.Name, $_.Value)
    }
    Write-Host "`n--- Detail ---" -ForegroundColor Cyan
    $details | ForEach-Object { Write-Host "  $_" }
}

function New-AtlasUser {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $Matricule,
        [Parameter(Mandatory)][string] $Prenom,
        [Parameter(Mandatory)][string] $Nom,
        [Parameter(Mandatory)][string] $Service,
        [Parameter(Mandatory)][string] $OUUtilisateurs,
        [Parameter(Mandatory)][securestring] $MotDePasse
    )

    # L'ANCRE : on cherche par matricule, jamais par nom
    $existant = Get-ADUser -Filter "EmployeeID -eq '$Matricule'" -ErrorAction SilentlyContinue

    if ($existant) {
        if ($PSCmdlet.ShouldProcess($Matricule, 'Mettre a jour')) {
            Set-ADUser -Identity $existant -Department $Service
        }
        return [pscustomobject]@{ Matricule = $Matricule; Action = 'MAJ' }
    }

    $ou   = "OU=$Service,$OUUtilisateurs"
    $base = '{0}.{1}' -f $Prenom.Substring(0,1), $Nom
    $sam  = Get-AtlasUniqueSam  -Base $base
    $upn  = Get-AtlasUniqueUpn  -Base $sam           -Suffixe 'corp.atlas.lab'
    $cn   = Get-AtlasUniqueCn   -Base "$Prenom $Nom" -Chemin  $ou

    if ($PSCmdlet.ShouldProcess($Matricule, 'Creer')) {
        New-ADUser `
            -Name              $cn `
            -GivenName         $Prenom `
            -Surname           $Nom `
            -DisplayName       "$Prenom $Nom" `
            -SamAccountName    $sam `
            -UserPrincipalName $upn `
            -EmployeeID        $Matricule `
            -Path              $ou `
            -Department        $Service `
            -AccountPassword   $MotDePasse `
            -Enabled           $true `
            -ChangePasswordAtLogon $true

        Add-ADGroupMember -Identity "GG-$Service" -Members $sam -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Matricule = $Matricule; Action = 'Cree' }
    }
    return [pscustomobject]@{ Matricule = $Matricule; Action = 'Simule' }
}

# --- Exporte les fonctions publiques ---
Export-ModuleMember -Function Get-AtlasWellKnownSid, Get-AtlasUniqueUpn,
                              Get-AtlasUniqueCn, Get-AtlasUniqueSam, New-AtlasUser, Disable-AtlasUser,
                              Invoke-AtlasOffboarding,Sync-AtlasFromSIRH
