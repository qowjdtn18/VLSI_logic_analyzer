[CmdletBinding()]
param(
    [ValidateSet('all', 'led', 'capture')]
    [string]$Target = 'all',

    [switch]$Wave,

    [string]$ToolDirectory
)

# Run the local testbenches without filling in their verification TODOs.
# -Wave explicitly requests a GTKWave window for one target.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Wave -and $Target -eq 'all') {
    throw 'With -Wave, choose -Target led or -Target capture.'
}

function Find-HdlTool {
    param([string]$Name)

    if ($ToolDirectory) {
        $candidate = Join-Path $ToolDirectory "$Name.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
        throw "Missing tool: $candidate"
    }

    $command = Get-Command "$Name.exe" -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    # Support terminals opened before the PATH update.
    $candidate = Join-Path "$($env:SystemDrive)\" "msys64\ucrt64\bin\$Name.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return $candidate
    }
    throw "Cannot find $Name. Install the tools described in README.md, or pass -ToolDirectory."
}

$iverilog = Find-HdlTool 'iverilog'
$vvp = Find-HdlTool 'vvp'
$gtkwave = if ($Wave) { Find-HdlTool 'gtkwave' } else { $null }
$repoRoot = Split-Path -Parent $PSScriptRoot
$targets = if ($Target -eq 'all') { @('led', 'capture') } else { @($Target) }
$designs = @{
    led = @{
        Top = 'tb_led_blink'
        Sources = @('rtl/led_blink.sv', 'tb/tb_led_blink.sv')
    }
    capture = @{
        Top = 'tb_logic_analyzer'
        Sources = @('rtl/logic_analyzer.sv', 'tb/tb_logic_analyzer.sv')
    }
}
$originalProcessPath = $env:Path
$toolBins = @($iverilog, $vvp, $gtkwave) | Where-Object { $_ } | ForEach-Object { Split-Path -Parent $_ } | Select-Object -Unique

Push-Location -LiteralPath $repoRoot
try {
    # Let child processes such as ivl find the MSYS2 runtime DLLs.
    # Apply this only to the current run and restore PATH on exit.
    $env:Path = ($toolBins -join ';') + ';' + $originalProcessPath
    New-Item -ItemType Directory -Force -Path 'build' | Out-Null

    foreach ($item in $targets) {
        $design = $designs[$item]
        $top = $design.Top
        $sources = $design.Sources
        $compiledPath = Join-Path $repoRoot "build/$top.vvp"
        $wavePath = Join-Path $repoRoot "build/$top.vcd"

        Write-Host "[$item] Compiling $top"
        & $iverilog -g2012 -Wall -s $top -o $compiledPath @sources
        if ($LASTEXITCODE -ne 0) {
            throw "Compilation failed for $top (exit $LASTEXITCODE). Simulation was not started."
        }

        Write-Host "[$item] Running $top"
        & $vvp $compiledPath
        if ($LASTEXITCODE -ne 0) {
            throw "Simulation failed for $top (exit $LASTEXITCODE)."
        }
        if (-not (Test-Path -LiteralPath $wavePath -PathType Leaf)) {
            throw "Simulation did not produce the expected VCD: $wavePath"
        }

        Write-Host "[$item] Waveform: $wavePath"
        if ($Wave) {
            Start-Process -FilePath $gtkwave -ArgumentList @("`"$wavePath`"") -WorkingDirectory $repoRoot -WindowStyle Normal
        }
    }

    Write-Host 'Commands completed. See testbench output for checks; SKELETON ONLY is not a functional pass.'
}
finally {
    $env:Path = $originalProcessPath
    Pop-Location
}
