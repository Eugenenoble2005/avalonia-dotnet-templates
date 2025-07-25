# Enable common parameters e.g. -Verbose
[CmdletBinding()]
param()

Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

# Taken from psake https://github.com/psake/psake
<#
.SYNOPSIS
  This is a helper function that runs a scriptblock and checks the PS variable $lastexitcode
  to see if an error occcured. If an error is detected then an exception is thrown.
  This function allows you to run command-line programs without having to
  explicitly check the $lastexitcode variable.
.EXAMPLE
  exec { svn info $repository_trunk } "Error executing SVN. Please verify SVN command-line client is installed"
#>
function Exec
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
        [Parameter(Position=1,Mandatory=0)][string]$errorMessage = ("Error executing command {0}" -f $cmd)
    )    

    # Convert the ScriptBlock to a string and expand the variables
    $expandedCmdString = $ExecutionContext.InvokeCommand.ExpandString($cmd.ToString())    
    Write-Verbose "Executing command: $expandedCmdString"

    Invoke-Command -ScriptBlock $cmd
    
    if ($lastexitcode -ne 0) {
        throw ("Exec: " + $errorMessage)
    }
}

function Test-Template {
    param (
        [Parameter(Position=0,Mandatory=1)][string]$template,
        [Parameter(Position=1,Mandatory=1)][string]$name,
        [Parameter(Position=2,Mandatory=1)][string]$lang,
        [Parameter(Position=3,Mandatory=1)][string]$parameterName,
        [Parameter(Position=4,Mandatory=1)][string]$value,
        [Parameter(Position=5,Mandatory=0)][string]$bl
    )

    $outDir = [IO.Path]::GetFullPath([IO.Path]::Combine($pwd, "..", "output"))
    $folderName = $name + $parameterName + $value
    
    # Remove dots and - from folderName because in sln it will cause errors when building project
    $folderName = $folderName -replace "[.-]"
    
    # Create the project
    Exec { dotnet new $template -o $outDir/$lang/$folderName -$parameterName $value -lang $lang }

    # Instantiate each item template in the project
    Exec { dotnet new avalonia.resource -o $outDir/$lang/$folderName -n NewResourceDictionary }
    Exec { dotnet new avalonia.styles -o $outDir/$lang/$folderName -n NewStyles }
    Exec { dotnet new avalonia.usercontrol -o $outDir/$lang/$folderName -n NewUserControl -lang $lang }
    Exec { dotnet new avalonia.window -o $outDir/$lang/$folderName -n NewWindow -lang $lang }
    If($lang -eq "F#")
    {
        $fsprojPath = [IO.Path]::Combine($outDir, $lang, $folderName, $folderName + '.fsproj')

        [xml]$doc = Get-Content $fsprojPath
        $item = $doc.CreateElement('Compile')
        $item.SetAttribute('Include', 'NewUserControl.axaml.fs')
        $doc.Project.ItemGroup[0].PrependChild($item)
        $item = $doc.CreateElement('Compile')
        $item.SetAttribute('Include', 'NewWindow.axaml.fs')
        $doc.Project.ItemGroup[0].PrependChild($item)
        $doc.Save($fsprojPath)
    }

    # Build
    Exec { dotnet build $outDir/$lang/$folderName -bl:$bl }
}

function Create-And-Build {
    param (
        [Parameter(Position=0,Mandatory=1)][string]$template,
        [Parameter(Position=1,Mandatory=1)][string]$name,
        [Parameter(Position=2,Mandatory=1)][string]$lang,
        [Parameter(Position=3,Mandatory=1)][string]$parameterName,
        [Parameter(Position=4,Mandatory=1)][string]$value,
        [Parameter(Position=5,Mandatory=0)][string]$bl
    )
    
    $folderName = $name + $parameterName + $value
    
    # Remove dots and - from folderName because in sln it will cause errors when building project
    $folderName = $folderName -replace "[.-]"

    # Create the project
    Exec { dotnet new $template -o output/$lang/$folderName -$parameterName $value -lang $lang }

    # Build
    Exec { dotnet build output/$lang/$folderName -bl:$bl }
}

# Clear file system from possible previous runs
Write-Output "Clearing outputs from possible previous runs"
if (Test-Path "output" -ErrorAction SilentlyContinue) {
    Remove-Item -Recurse -Force "output"
}
$outDir = [IO.Path]::GetFullPath([IO.Path]::Combine($pwd, "..", "output"))
if (Test-Path $outDir -ErrorAction SilentlyContinue) {
    Remove-Item -Recurse -Force $outDir
}
$binLogDir = [IO.Path]::GetFullPath([IO.Path]::Combine($pwd, "..", "binlog"))
if (Test-Path $binLogDir -ErrorAction SilentlyContinue) {
    Remove-Item -Recurse -Force $binLogDir
}

# Use same log file for all executions
$binlog = [IO.Path]::GetFullPath([IO.Path]::Combine($pwd, "..", "binlog", "test.binlog"))

Create-And-Build "avalonia.app" "AvaloniaApp" "C#" "f" "net9.0" $binlog
Create-And-Build "avalonia.app" "AvaloniaApp" "C#" "av" "11.3.2" $binlog
Create-And-Build "avalonia.app" "AvaloniaApp" "C#" "cb" "true" $binlog
Create-And-Build "avalonia.app" "AvaloniaApp" "C#" "cb" "false" $binlog

# Build the project only twice with all item templates,once with .net6.0 tfm and once with .net7.0 tfm for C# and F#
Test-Template "avalonia.mvvm" "AvaloniaMvvm" "C#" "f" "net9.0" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "C#" "av" "11.3.2" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "C#" "m" "ReactiveUI" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "C#" "m" "CommunityToolkit" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "C#" "cb" "true" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "C#" "cb" "false" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "C#" "rvl" "true" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "C#" "rvl" "false" $binlog

Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "f" "net8.0" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "f" "net9.0" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "cpm" "true" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "cpm" "false" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "av" "11.3.2" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "m" "ReactiveUI" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "m" "CommunityToolkit" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "cb" "true" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "cb" "false" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "rvl" "true" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "C#" "rvl" "false" $binlog

# Ignore errors when files are still used by another process
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "output/C#"

Create-And-Build "avalonia.app" "AvaloniaApp" "F#" "f" "net9.0" $binlog
Create-And-Build "avalonia.app" "AvaloniaApp" "F#" "av" "11.3.2" $binlog
Create-And-Build "avalonia.app" "AvaloniaApp" "F#" "cb" "true" $binlog
Create-And-Build "avalonia.app" "AvaloniaApp" "F#" "cb" "false" $binlog

Test-Template "avalonia.mvvm" "AvaloniaMvvm" "F#" "f" "net9.0" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "F#" "av" "11.3.2" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "F#" "m" "ReactiveUI" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "F#" "m" "CommunityToolkit" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "F#" "cb" "true" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "F#" "cb" "false" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "F#" "rvl" "true" $binlog
Create-And-Build "avalonia.mvvm" "AvaloniaMvvm" "F#" "rvl" "false" $binlog

Create-And-Build "avalonia.xplat" "AvaloniaXplat" "F#" "f" "net9.0" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "F#" "av" "11.3.2" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "F#" "m" "ReactiveUI" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "F#" "m" "CommunityToolkit" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "F#" "cb" "true" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "F#" "cb" "false" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "F#" "rvl" "true" $binlog
Create-And-Build "avalonia.xplat" "AvaloniaXplat" "F#" "rvl" "false" $binlog

# Ignore errors when files are still used by another process
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "output/F#"
