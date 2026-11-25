function Get-CPUTemperature {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$Detailed
    )

    $temperature = $null
    $sensorName = "CPU temperature sensor unavailable"
    $sensorFound = $false
    $requiresElevation = $false
    $computer = $null

    try {
        $libraryPath = Join-Path $Root "Tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
        if (-not (Test-Path -LiteralPath $libraryPath)) {
            throw "LibreHardwareMonitorLib.dll was not found."
        }

        [void][Reflection.Assembly]::LoadFrom($libraryPath)
        $computer = New-Object LibreHardwareMonitor.Hardware.Computer
        $computer.IsCpuEnabled = $true
        $computer.Open()

        $temperatureSensors = @()
        $hardwareStack = New-Object System.Collections.Stack
        foreach ($hardware in $computer.Hardware) {
            $hardwareStack.Push($hardware)
        }

        while ($hardwareStack.Count -gt 0) {
            $hardware = $hardwareStack.Pop()
            $hardware.Update()
            foreach ($sensor in $hardware.Sensors) {
                if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                    $temperatureSensors += $sensor
                }
            }
            foreach ($subHardware in $hardware.SubHardware) {
                $hardwareStack.Push($subHardware)
            }
        }

        $preferredNames = @("CPU Package", "Core Max", "Core Average", "CPU Die", "Tctl/Tdie", "CPU Core")
        $selectedSensor = $null
        foreach ($preferredName in $preferredNames) {
            $matchingSensors = @($temperatureSensors | Where-Object {
                $_.Name -match [regex]::Escape($preferredName)
            })
            $selectedSensor = $matchingSensors |
                Where-Object { $null -ne $_.Value } |
                Select-Object -First 1
            if ($selectedSensor) {
                break
            }
            if (-not $selectedSensor -and $matchingSensors.Count -gt 0) {
                $selectedSensor = $matchingSensors[0]
            }
        }

        if ($selectedSensor) {
            $sensorFound = $true
            $sensorName = $selectedSensor.Name
            if ($null -ne $selectedSensor.Value) {
                $temperature = [math]::Round([double]$selectedSensor.Value, 1)
            } else {
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = New-Object Security.Principal.WindowsPrincipal($identity)
                $requiresElevation = -not $principal.IsInRole(
                    [Security.Principal.WindowsBuiltInRole]::Administrator
                )
                if ($requiresElevation) {
                    $sensorName = "Run as administrator to read $sensorName"
                } else {
                    $sensorName = "$sensorName returned no value"
                }
            }
        }
    }
    catch {
        $sensorName = "Hardware sensor read failed: $($_.Exception.Message)"
    }
    finally {
        if ($computer) {
            $computer.Close()
        }
    }

    if ($Detailed) {
        return [PSCustomObject]@{
            Temperature = $temperature
            Sensor = $sensorName
            SensorFound = $sensorFound
            RequiresElevation = $requiresElevation
        }
    }

    return $temperature
}
