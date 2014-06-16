# 
# File: NuGet.psm1
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



$here = Split-Path $MyInvocation.MyCommand.Path





New-Variable ToRootNamespace {
    param ($AssemblyInfo)
    $AssemblyInfo.GetName().Name + '.Prig'
} -Option ReadOnly



New-Variable ToSignAssembly {
    param ($KeyFile)
    if ([string]::IsNullOrEmpty($KeyFile)) {
        $false
    } else {
        $true
    }
} -Option ReadOnly



New-Variable ToProcessorArchitectureConstant {
    param ($AssemblyInfo)

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "_M_IX86" }
        'Amd64'     { "_M_AMD64" }
        'MSIL'      { "_M_MSIL" }
        Default     { "_M_MSIL" }
    }
} -Option ReadOnly



New-Variable ToTargetFrameworkVersionConstant {
    param ($TargetFrameworkVersion)
    
    switch ($TargetFrameworkVersion)
    {
        'v3.5'      { "_NET_3_5" }
        'v4.0'      { "_NET_4" }
        'v4.5'      { "_NET_4_5" }
        'v4.5.1'    { "_NET_4_5_1" }
        Default     { "_NET_4" }
    }
} -Option ReadOnly



New-Variable ToDefineConstants {
    param ($AssemblyInfo, $TargetFrameworkVersion)
    $result = (& $ToProcessorArchitectureConstant $AssemblyInfo), (& $ToTargetFrameworkVersionConstant $TargetFrameworkVersion)
    $result -join ';'
} -Option ReadOnly



New-Variable ToPlatformTarget {
    param ($AssemblyInfo)

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "x86" }
        'Amd64'     { "x64" }
        'MSIL'      { "AnyCPU" }
        Default     { "AnyCPU" }
    }
} -Option ReadOnly



New-Variable ToProcessorArchitectureString {
    param (
        [Parameter(Mandatory = $True)]
        $Info
    )

    switch ($Info)
    {
        { $_.psobject.TypeNames -contains 'System.Reflection.Assembly' } {  
            $procArch = [string]$Info.GetName().ProcessorArchitecture 
        }
        { $_.psobject.TypeNames -contains 'System.Reflection.AssemblyName' } {  
            $procArch = [string]$Info.ProcessorArchitecture 
        }
        { $_.psobject.TypeNames -contains 'Urasandesu.Prig.NuGet.AssemblyNameEx' } {  
            $procArch = $Info.ProcessorArchitecture 
        }
        { $_ -is [string] } { 
            $procArch = $Info 
        }
        Default { 
            throw New-Object System.ArgumentException ('Parameter $Info({0}) is not supported.' -f $Info.GetType()) 
        }
    }

    switch ($procArch)
    {
        'X86'                           { "x86" }
        { $_ -match '(Amd64)|(x64)' }   { "AMD64" }
        { $_ -match '(MSIL)|(AnyCPU)' } { "MSIL" }
        Default                         { "MSIL" }
    }
} -Option ReadOnly



New-Variable ToReferenceInclude {
    param ($refAsmInfos)
    
    foreach ($refAsmInfo in $refAsmInfos) {
        @"
        <Reference Include="$($refAsmInfo.GetName().Name)">
            <HintPath>$($refAsmInfo.Location)</HintPath>
        </Reference>
"@
    }
} -Option ReadOnly



New-Variable ToFullNameFromType {
    param ($Type)
    
    $defName = $Type.FullName
    
    if ($Type.IsGenericType -and !$Type.IsGenericTypeDefinition)
    {
        $defName = $Type.Namespace + "." + $Type.Name
    } elseif ($Type.ContainsGenericParameters) {
        $defName = $Type.Name
    }

    if ($Type.IsGenericType) {
        $defName = $defName -replace '`\d+', ''
        $genericArgNames = @()
        foreach ($genericArg in $Type.GetGenericArguments()) {
            $genericArgNames += (& $ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }

    $defName
} -Option ReadOnly



New-Variable ToClassNameFromType {
    param ($Type)
    $defName = $Type.Name
    if ($Type.IsGenericType) {
        $defName = $defName -replace '`\d+', ''
        $genericArgNames = @()
        foreach ($genericArg in $Type.GetGenericArguments()) {
            $genericArgNames += (& $ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
} -Option ReadOnly



New-Variable ToBaseNameFromType {
    param ($Type)
    $defName = $Type.Name
    if ($Type.IsGenericType) {
        $defName = $defName -replace '`\d+', ''
    }
    $defName + "Base"
} -Option ReadOnly



New-Variable ToClassNameFromStub {
    param ($Stub)
    $defName = $Stub.Alias
    if ($Stub.Target.IsGenericMethod) {
        $defName = $defName -replace '`\d+', ''
        $genericArgNames = @()
        foreach ($genericArg in $Stub.Target.GetGenericArguments()) {
            $genericArgNames += (& $ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
} -Option ReadOnly





. $(Join-Path $here NuGet.Add-PrigAssembly.ps1)
. $(Join-Path $here NuGet.ConvertTo-PrigAssemblyName.ps1)
. $(Join-Path $here NuGet.Find-IndirectionTarget.ps1)
. $(Join-Path $here NuGet.Get-IndirectionStubSetting.ps1)
. $(Join-Path $here NuGet.New-PrigCsproj.ps1)
. $(Join-Path $here NuGet.New-PrigStubsCs.ps1)
. $(Join-Path $here NuGet.New-PrigTokensCs.ps1)





Export-ModuleMember -Function *-* -Alias *
