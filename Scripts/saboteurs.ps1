# ============================================================
#  SABOTEURS — Module 5
#  Lance UNE fonction, diagnostique, repare, puis passe a la suivante.
#  Ne lis pas le detail : diagnostique le symptome.
# ============================================================

function Panne-01 { Stop-Service Netlogon -Force; Set-Service Netlogon -StartupType Disabled }

function Panne-02 {
    $z='corp.atlas.lab'
    Get-DnsServerResourceRecord -ZoneName $z -RRType Srv |
        Where-Object { $_.RecordData.DomainName -like '*DC01*' -and $_.HostName -like '*_ldap*' } |
        ForEach-Object { Remove-DnsServerResourceRecord -ZoneName $z -InputObject $_ -Force }
}

function Panne-03 {
    $sam='j.dupont'
    Get-ADUser $sam | Disable-ADAccount
}

function Panne-04 {
    Set-DnsClientServerAddress -InterfaceAlias (Get-NetAdapter|?{$_.Status -eq 'Up'}).Name -ServerAddresses '8.8.8.8'
}

function Panne-05 {
    $g='ATLAS-Baseline-Postes'
    $gpo=Get-GPO -Name $g
    # Retire "Utilisateurs authentifies" du filtrage de securite
    $sid=(Get-ADGroup 'Domain Computers').SID
    try { Set-GPPermission -Name $g -TargetName 'Authenticated Users' -TargetType Group -PermissionLevel None -Confirm:$false } catch {}
}

function Panne-06 {
    $sam='m.martin'
    0..6 | ForEach-Object {
        try { Get-ADUser $sam; $null = New-Object DirectoryServices.DirectoryEntry(
            "LDAP://DC01","$sam@corp.atlas.lab","MauvaisMotDePasse!") } catch {}
    }
    # Force un verrouillage via mauvaises tentatives simulees si politique active
    Write-Host "Panne-06 armee sur $sam"
}

function Panne-07 {
    w32tm /config /manualpeerlist:"192.168.99.99" /syncfromflags:manual /update
    Restart-Service w32time
}

function Panne-08 {
    Stop-Service DNS -Force
    Set-Service DNS -StartupType Disabled
}

function Panne-09 {
    $z='corp.atlas.lab'
    Set-DnsServerPrimaryZone -Name $z -DynamicUpdate None
}

function Panne-10 {
    New-NetFirewallRule -DisplayName 'SABOTAGE-Bloque-LDAP' -Direction Inbound `
        -Protocol TCP -LocalPort 389 -Action Block -Enabled True | Out-Null
}

Write-Host "Saboteurs charges. Lance une panne : Panne-01, Panne-02, ..." -ForegroundColor Yellow