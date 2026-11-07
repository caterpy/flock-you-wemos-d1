[CmdletBinding()]
param(
    [string]$Port,
    [switch]$NoFlash,
    [switch]$NoRun,
    [string]$HostAddress = '127.0.0.1',
    [ValidateRange(1, 65535)]
    [int]$HttpPort = 5000,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
    @'
Usage: .\install_windows.ps1 [options]

Set up the dashboard's Python environment, optionally flash a connected
Wemos D1 mini, then run the dashboard.

Options:
  -Port COM5       Serial port to flash (asks before flashing)
  -NoFlash         Set up the dashboard without building/flashing firmware
  -NoRun           Install only; do not start the dashboard
  -HostAddress IP  Dashboard bind address (default: 127.0.0.1)
  -HttpPort PORT   Dashboard port (default: 5000)
  -Help            Show this help

If -Port is omitted, a single detected CH340/WCH serial device is offered
for confirmation. Otherwise flashing is skipped; the port can be selected
from the dashboard later.
'@
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)]
        [string]$Executable,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Executable $($Arguments -join ' ')"
    }
}

if ($Help) {
    Show-Usage
    exit 0
}

$RootDir = $PSScriptRoot
$ApiDir = Join-Path $RootDir 'api'
$VenvDir = Join-Path $ApiDir '.venv'
$Requirements = Join-Path $ApiDir 'requirements.txt'

if (-not (Test-Path -LiteralPath $Requirements -PathType Leaf)) {
    throw "Dashboard requirements were not found at $Requirements. Run this script from a project checkout."
}

$PythonLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($PythonLauncher) {
    $PythonExecutable = $PythonLauncher.Source
    $PythonPrefix = @('-3')
} else {
    $PythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $PythonCommand) {
        throw 'Python 3 was not found. Install Python 3.8 or newer and rerun this script.'
    }
    $PythonExecutable = $PythonCommand.Source
    $PythonPrefix = @()
}

Invoke-Checked -Executable $PythonExecutable -Arguments ($PythonPrefix + @(
    '-c',
    'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'
))

if (-not (Test-Path -LiteralPath (Join-Path $VenvDir 'Scripts\python.exe'))) {
    Invoke-Checked -Executable $PythonExecutable -Arguments ($PythonPrefix + @('-m', 'venv', $VenvDir))
}

$VenvPython = Join-Path $VenvDir 'Scripts\python.exe'
Invoke-Checked -Executable $VenvPython -Arguments @('-m', 'pip', 'install', '--upgrade', 'pip')
Invoke-Checked -Executable $VenvPython -Arguments @('-m', 'pip', 'install', '-r', $Requirements)

if (-not $NoFlash) {
    Invoke-Checked -Executable $VenvPython -Arguments @('-m', 'pip', 'install', 'platformio')

    $SerialPorts = @([System.IO.Ports.SerialPort]::GetPortNames())
    $UsbSerialPorts = @(
        Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DeviceID -in $SerialPorts -and
                $_.Name -match '(?i)CH340|CH341|WCH|USB.?SERIAL'
            } |
            Select-Object -ExpandProperty DeviceID -Unique
    )

    if (-not $Port) {
        if ($UsbSerialPorts.Count -eq 1) {
            $Port = $UsbSerialPorts[0]
            Write-Host "Detected CH340/WCH serial device: $Port"
        } elseif ($UsbSerialPorts.Count -gt 1) {
            Write-Warning "Multiple CH340/WCH serial devices found: $($UsbSerialPorts -join ', '). Specify -Port explicitly to choose one."
        } else {
            Write-Host 'No Wemos-compatible CH340/WCH port detected; skipping firmware flash.'
        }
    }

    if ($Port) {
        if ($Port -notin $SerialPorts) {
            throw "Serial port $Port was not found. Connect the Wemos and check Device Manager for its COM port."
        }

        $Confirmation = Read-Host "Flash Wemos D1 mini firmware to $Port? [y/N]"
        if ($Confirmation -match '^(?i:y|yes)$') {
            Invoke-Checked -Executable $VenvPython -Arguments @(
                '-m', 'platformio', 'run', '-d', $RootDir,
                '-e', 'd1_mini', '-t', 'upload', '--upload-port', $Port
            )
        } else {
            Write-Host 'Skipping firmware flash.'
        }
    } elseif ($UsbSerialPorts.Count -gt 1) {
        Write-Host 'Connect the board to the dashboard later and choose its COM port there.'
    }
}

if ($NoRun) {
    Write-Host "`nInstall complete. Start the dashboard with:"
    Write-Host "  Set-Location '$ApiDir'"
    Write-Host "  & '$VenvPython' flockyou.py"
    exit 0
}

Write-Host "`nDashboard: http://localhost:$HttpPort"
Write-Host 'Select the Wemos COM port under Sniffer and click Connect.'
Write-Host 'Close Serial Monitor or any other program using the Wemos COM port.'
Write-Host 'Press Ctrl+C to stop the dashboard.'

$PreviousHost = $env:FLOCKYOU_HOST
$PreviousPort = $env:FLOCKYOU_PORT
try {
    $env:FLOCKYOU_HOST = $HostAddress
    $env:FLOCKYOU_PORT = [string]$HttpPort
    Push-Location $ApiDir
    try {
        & $VenvPython (Join-Path $ApiDir 'flockyou.py')
        if ($LASTEXITCODE -ne 0) {
            throw "Dashboard exited with code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
} finally {
    $env:FLOCKYOU_HOST = $PreviousHost
    $env:FLOCKYOU_PORT = $PreviousPort
}
