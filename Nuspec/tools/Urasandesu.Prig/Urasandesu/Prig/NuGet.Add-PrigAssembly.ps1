# 
# File: NuGet.Add-PrigAssembly.ps1
# 
# Author: Akira Sugiura (urasandesu@gmail.com)
# 
# 
# Copyright (c) 2012 Akira Sugiura
#  
#  This software is MIT License.
#  
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#

function Add-PrigAssembly {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Assembly
    )

    $os = Get-WmiObject Win32_OperatingSystem
    [System.Reflection.ProcessorArchitecture]$osArch = 0
    $osArch = $(if ($os.OSArchitecture -match '64') { 'Amd64' } else { 'X86' })

    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Build')
    $msbProjCollection = [Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection
    $envProj = (Get-Project).Object.Project
    $allMsbProjs = $msbProjCollection.GetLoadedProjects($envProj.FullName).GetEnumerator();
    if(!$allMsbProjs.MoveNext()) {
        throw New-Object System.InvalidOperationException ('"{0}" has not been loaded.' -f $envProj.FullName)
    }
    $curMsbProj = $allMsbProjs.Current

    $platformTargets = New-Object 'System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[System.Reflection.ProcessorArchitecture]]'
    if (!$curMsbProj.ConditionedProperties.ContainsKey('Platform')) {
        $platformTargets['AnyCPU'] = New-Object 'System.Collections.Generic.List[System.Reflection.ProcessorArchitecture]'
        $platformTargets['AnyCPU'].Add($osArch)
        $platformTargets['AnyCPU'].Add('MSIL')
    } else {
        foreach ($conditionedProperty in $curMsbProj.ConditionedProperties['Platform']) {
            $platformTargets[$conditionedProperty] = New-Object 'System.Collections.Generic.List[System.Reflection.ProcessorArchitecture]'
            [System.Reflection.ProcessorArchitecture]$1stCandidateArch = 0
            $1stCandidateArch = & $ToProcessorArchitectureString $conditionedProperty
            $1stCandidateArch = $(if ($1stCandidateArch -eq 'MSIL') { $osArch } else { $1stCandidateArch })
            $platformTargets[$conditionedProperty].Add($1stCandidateArch)
            $platformTargets[$conditionedProperty].Add('MSIL')
        }
    }

    $curMsbProj.MarkDirty()

    $candidateNames = GetGACAssemblyNameExs $Assembly
    if ($candidateNames.Length -eq 0) {
        throw New-Object System.IO.FileNotFoundException ('Assembly ''{0}'' is not found.' -f $Assembly)
    }
    
    foreach ($platformTarget in $platformTargets.GetEnumerator()) {
        $actualNames = New-Object System.Collections.ArrayList
        foreach ($candidateName in $candidateNames) {
            if ($platformTarget.Value.Contains($candidateName.ProcessorArchitecture)) {
                [void]$actualNames.Add($candidateName)
            }
        }
        if ($actualNames.Count -eq 0) {
            throw New-Object System.BadImageFormatException ('Assembly ''{0}'' is mismatch to the specified platform ''{1}''.' -f $Assembly, $platformTarget.Key)
        }
        if (1 -lt $actualNames.Count) {
            throw New-Object System.BadImageFormatException ("Ambiguous match found: `r`n{0}" -f ([string]::Join("`r`n", ($actualNames | % { $_.FullName }))))
        }
        
        SetPrigAssemblyReferenceItem $curMsbProj $actualNames[0] $platformTarget.Key
        SetStubberPreBuildEventProperty $curMsbProj $actualNames[0] $platformTarget.Key $platformTarget.Value[0]
    }

    SetStubSettingNoneItem $curMsbProj $actualNames[0] $envProj.FullName

    $curMsbProj.Save()
}

New-Alias PAdd Add-PrigAssembly



function GetGACAssemblyNameExs {
    param ($Assembly)
#    $csv = @"
#Name,Version,Culture,PublicKeyToken,ProcessorArchitecture,FullName,ImageRuntimeVersion
#mscorlib,4.0.0.0,,b77a5c561934e089,x86,"mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089",v4.0.30319
#mscorlib,4.0.0.0,,b77a5c561934e089,AMD64,"mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089",v4.0.30319
#"@

#    $results = $csv | ConvertFrom-Csv
    $results = prig dasm -assembly $Assembly | ConvertFrom-Csv
    foreach ($result in $results) {
        $result.psobject.TypeNames.Insert(0, 'Urasandesu.Prig.NuGet.AssemblyNameEx')
        $result
    }
}



function SetPrigAssemblyReferenceItem {

    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Build.Evaluation.Project]
        $MSBuildProject,

        [Parameter(Mandatory = $true)]
        $AssemblyNameEx,

        [Parameter(Mandatory = $true)]
        [string]
        $Platform
    )

    $reference = $MSBuildProject.AddItem('Reference', (ConvertTo-PrigAssemblyName $AssemblyNameEx))
    $reference[0].Xml.Condition = "'`$(Platform)' == '$Platform'"
}



function SetStubberPreBuildEventProperty {

    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Build.Evaluation.Project]
        $MSBuildProject,

        [Parameter(Mandatory = $true)]
        $AssemblyNameEx,

        [Parameter(Mandatory = $true)]
        [string]
        $Platform, 

        [Parameter(Mandatory = $true)]
        [System.Reflection.ProcessorArchitecture]
        $ProcessorArchitecture
    )

    $prigPkg = Get-Package Prig
    $prigPkgName = $prigPkg.Id + '.' + $prigPkg.Version
    $powershell = $(if ($ProcessorArchitecture -eq 'Amd64') { '%windir%\SysNative\WindowsPowerShell\v1.0\powershell.exe' } else { '%windir%\system32\WindowsPowerShell\v1.0\powershell.exe' })
    $argFile = '-File "$(SolutionDir)packages\{0}\tools\Invoke-PilotStubber.ps1"' -f $prigPkgName
    $argAssembly = '-Assembly "{0}"' -f $AssemblyNameEx.FullName
    $argTargetFrameworkVersion = '-TargetFrameworkVersion {0}' -f $MSBuildProject.GetProperty('TargetFrameworkVersion').EvaluatedValue
    if ($MSBuildProject.GetProperty('TargetFrameworkVersion').EvaluatedValue -eq 'v3.5') {
        $argOther = '-Version 2.0 -NoLogo -NoProfile'
        $argReferenceFrom = '-ReferenceFrom "@(''$(SolutionDir)packages\{0}\lib\net35\Urasandesu.NAnonym.dll'',''$(SolutionDir)packages\{0}\lib\net35\Urasandesu.Prig.Framework.dll'')"' -f $prigPkgName
    } else {
        $argOther = '-NoLogo -NoProfile'
        $argReferenceFrom = '-ReferenceFrom "@(''$(SolutionDir)packages\{0}\lib\net40\Urasandesu.NAnonym.dll'',''$(SolutionDir)packages\{0}\lib\net40\Urasandesu.Prig.Framework.dll'')"' -f $prigPkgName
    }
    $argKeyFile = '-KeyFile "$(SolutionDir)packages\{0}\tools\Urasandesu.Prig.snk"' -f $prigPkgName
    $argOutputPath = '-OutputPath "{0}."' -f $MSBuildProject.ExpandString('$(TargetDir)')
    $argSettings = '-Settings "{0}{1}.prig"' -f $MSBuildProject.ExpandString('$(ProjectDir)'), $AssemblyNameEx.Name
    $cmd = 'cmd /c " "%VS120COMNTOOLS%VsDevCmd.bat" & {0} {1} {2} {3} {4} {5} {6} {7} {8} "' -f 
                $powershell, 
                $argOther, 
                $argFile, 
                $argReferenceFrom, 
                $argAssembly, 
                $argTargetFrameworkVersion, 
                $argKeyFile, 
                $argOutputPath, 
                $argSettings
        
    $propGroup = $MSBuildProject.Xml.AddPropertyGroup()
    $propGroup.Condition = "'`$(Platform)' == '$Platform'"
    [void]$propGroup.AddProperty('PreBuildEvent', $cmd)
}



function SetStubSettingNoneItem {

    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Build.Evaluation.Project]
        $MSBuildProject,

        [Parameter(Mandatory = $true)]
        $AssemblyNameEx,

        [Parameter(Mandatory = $true)]
        [string]
        $ProjectFullName
    )

    [void]$MSBuildProject.AddItem('None', $AssemblyNameEx.Name + '.prig')
    $stubSetting = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($ProjectFullName), $AssemblyNameEx.Name + '.prig')
    if (![System.IO.File]::Exists($stubSetting)) {
        $tools = [System.IO.Path]::GetDirectoryName((Get-Command prig).Path)
        $stubSettingTemplate = [System.IO.Path]::Combine($tools, 'PilotStubber.prig')
        Copy-Item $stubSettingTemplate $stubSetting -ErrorAction Stop | Out-Null
    }
}