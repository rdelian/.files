# dir -> eza  
function l { eza --icons=auto -hAl --git @args }
function lt { eza --icons=auto -hAlT --git @args }
function ld { eza --icons=auto -hAlD --git @args }
function lf { eza --icons=auto -hAlf --git @args }

# Find using EveryThing + fzf
function f {
    param([string]$FileName)
    if ($FileName) {
        $selection = es $FileName | fzf
        if ($selection) { return $selection }
    }
}

# Find using EveryThing + fzf - open with nvim
function nvf {
    param([string]$FileName)
    if ($FileName) { $selection = es $FileName | fzf }
    if ($selection) { nvim $selection }
}

# Elevate to admin
function Launch-AdminPS {
    $currentDir = Get-Location
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit", "-Command", "Set-Location '$currentDir'"
}
Set-Alias -Name admin -Value Launch-AdminPS

# Execute command with admin in new term and return output in current
function Invoke-AdminCommand {
    if ($Args.Count -eq 0) {
        Write-Warning "Please specify a command. Example: adminc bun need-admin.js"
        return
    }
    $currentDir = Get-Location
    $commandString = $Args -join ' '
    $tempFile = [System.IO.Path]::GetTempFileName()
    $finalCommand = "Set-Location '$currentDir'; & $commandString 2>&1 | ForEach-Object { if (`$_ -is [System.Management.Automation.ErrorRecord]) { `$_.TargetObject } else { `$_ } } | Out-File -FilePath '$tempFile' -Encoding utf8"
    $process = Start-Process powershell -Verb RunAs -ArgumentList "-Command", $finalCommand -PassThru -Wait
    if (Test-Path $tempFile) {
        Get-Content $tempFile
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}
Set-Alias -Name adminc -Value Invoke-AdminCommand

# cd -> zoxide
Invoke-Expression (& zoxide init powershell | Out-String)
Set-Alias -Name cd -Value __zoxide_z -Option AllScope -Force

# Starship
function Invoke-Starship-TransientFunction { &starship module character }
Invoke-Expression (&starship init powershell | Out-String)
