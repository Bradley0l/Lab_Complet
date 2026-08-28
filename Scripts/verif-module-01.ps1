# Verification du Module 1
$global:ok = $true
function Test-Point($libelle, $condition) {
    $etat    = if ($condition) { 'PASS' } else { 'FAIL' }
    $couleur = if ($condition) { 'Green' } else { 'Red' }
    Write-Host ('{0,-48} {1}' -f $libelle, $etat) -ForegroundColor $couleur
    if (-not $condition) { $global:ok = $false }
}

Write-Host "`n=== Verification Module 1 ===`n" -ForegroundColor Cyan

Test-Point "Nom de la machine = DC01" ($env:COMPUTERNAME -eq 'DC01')

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -eq '192.168.56.10' })
Test-Point "IP fixe 192.168.56.10" ($null -ne $ip)

$dns = (Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object { $_.ServerAddresses -contains '127.0.0.1' -or
                       $_.ServerAddresses -contains '192.168.56.10' })
Test-Point "DNS pointe sur lui-meme" ($null -ne $dns)

Test-Point "Role AD DS installe" `
    ((Get-WindowsFeature AD-Domain-Services).InstallState -eq 'Installed')

$d = Get-ADDomain -ErrorAction SilentlyContinue
Test-Point "Domaine corp.atlas.lab"  ($d.DNSRoot     -eq 'corp.atlas.lab')
Test-Point "NetBIOS ATLAS"           ($d.NetBIOSName -eq 'ATLAS')
Test-Point "Niveau Windows2016Domain" ($d.DomainMode -eq 'Windows2016Domain')

$f = Get-ADForest -ErrorAction SilentlyContinue
Test-Point "Foret corp.atlas.lab"    ($f.Name -eq 'corp.atlas.lab')
Test-Point "DC01 est catalogue global" ($f.GlobalCatalogs -contains 'DC01.corp.atlas.lab')

Test-Point "Service NTDS demarre"    ((Get-Service NTDS).Status    -eq 'Running')
Test-Point "Service DNS demarre"     ((Get-Service DNS).Status     -eq 'Running')
Test-Point "Service Netlogon demarre" ((Get-Service Netlogon).Status -eq 'Running')
Test-Point "Service KDC demarre"     ((Get-Service kdc).Status     -eq 'Running')

$srv = Resolve-DnsName '_ldap._tcp.dc._msdcs.corp.atlas.lab' -Type SRV -ErrorAction SilentlyContinue
Test-Point "Enregistrement SRV _ldap present" ($null -ne $srv)

Test-Point "Partage SYSVOL present" `
    ($null -ne (Get-SmbShare -Name SYSVOL -ErrorAction SilentlyContinue))
Test-Point "Partage NETLOGON present" `
    ($null -ne (Get-SmbShare -Name NETLOGON -ErrorAction SilentlyContinue))

Write-Host ''
if ($global:ok) {
    Write-Host 'MODULE 1 VALIDE — domaine operationnel' -ForegroundColor Green
} else {
    Write-Host 'Corrige les FAIL avant le module 2' -ForegroundColor Yellow
}