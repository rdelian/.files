<#
.EXAMPLE
  .\quad9-dns.ps1
  # encrypted-preferred (plaintext fallback allowed, roaming-safe)
.EXAMPLE
  .\quad9-dns.ps1 -Reset
  # revert DNS to DHCP on the same adapters
#>
[CmdletBinding()]
param(
  [switch]$Reset
)

$ErrorActionPreference = 'Stop'

$IPv4         = @('9.9.9.10', '149.112.112.10')
$IPv6         = @('2620:fe::10', '2620:fe::fe:10')
$DohTemplate  = 'https://dns10.quad9.net/dns-query'
$AllowFallback = $true  # encrypted-preferred; plaintext fallback allowed (roaming-safe)

function Test-IsAdmin {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
  Write-Warning 'Not elevated. Re-run this script from an elevated PowerShell prompt.'
  exit 1
}

$adapters = Get-NetAdapter -Physical | Where-Object {
  $_.MediaType -eq '802.3' -and $_.Status -eq 'Up'
}
if (-not $adapters) {
  $adapters = Get-NetAdapter -Physical | Where-Object { $_.MediaType -eq '802.3' }
}
if (-not $adapters) { throw 'No Ethernet adapters found.' }

foreach ($a in $adapters) {
  if ($Reset) {
    Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses
    Write-Host "[$($a.Name)] DNS reset to DHCP."
    continue
  }
  Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ($IPv4 + $IPv6)
  Write-Host "[$($a.Name)] DNS -> $($IPv4 -join ', ') / $($IPv6 -join ', ')"
}

if (-not $Reset) {
  foreach ($ip in ($IPv4 + $IPv6)) {
    $exists = Get-DnsClientDohServerAddress -ServerAddress $ip -ErrorAction SilentlyContinue
    if ($exists) {
      Set-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate $DohTemplate `
        -AutoUpgrade $true -AllowFallbackToUdp $AllowFallback
    } else {
      Add-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate $DohTemplate `
        -AutoUpgrade $true -AllowFallbackToUdp $AllowFallback
    }
  }
  Write-Host "DoH template -> $DohTemplate (fallback to plaintext: $AllowFallback)"
  Write-Host '-- DoH registration --'
  $dohState = ($IPv4 + $IPv6) | ForEach-Object {
    Get-DnsClientDohServerAddress -ServerAddress $_ -ErrorAction SilentlyContinue
  }
  if (-not $dohState) {
    Write-Warning 'No DoH entries found - Settings will show Unencrypted.'
  } else {
    $dohState | Format-Table ServerAddress, DohTemplate, AutoUpgrade, AllowFallbackToUdp -AutoSize
    $bad = $dohState | Where-Object { $_.DohTemplate -ne $DohTemplate }
    if ($bad) {
      Write-Warning "Unexpected template on: $($bad.ServerAddress -join ', ')."
    }
  }
}

Write-Host '-- verify --'
Get-DnsClientServerAddress -InterfaceIndex $adapters.ifIndex -AddressFamily IPv4, IPv6 |
  Format-Table InterfaceAlias, AddressFamily, ServerAddresses -AutoSize
$transport = (Resolve-DnsName -Type txt proto.on.quad9.net. -ErrorAction SilentlyContinue).Strings
Write-Host "Quad9 transport: $transport (should say: doh)"

