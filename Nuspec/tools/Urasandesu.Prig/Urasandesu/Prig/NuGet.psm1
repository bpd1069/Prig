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





New-Variable AssemblyNameExTypeName 'Urasandesu.Prig.NuGet.AssemblyNameEx' -Option ReadOnly



function ConcatIfNonEmpty {
    param (
        [string]
        $String1,
         
        [string]
        $String2
    )

    if (![string]::IsNullOrEmpty($String1) -and ![string]::IsNullOrEmpty($String2)) {
        $String1 + $String2
    }
}



function ToRootNamespace {
    param ($AssemblyInfo)
    $AssemblyInfo.GetName().Name + '.Prig'
}



function ToSignAssembly {
    param ($AssemblyInfo, $KeyFile)
    if ($AssemblyInfo.GetName().GetPublicKeyToken().Length -eq 0) {
        $false
    } else {
        if ([string]::IsNullOrEmpty($KeyFile)) {
            $false
        } else {
            $true
        }
    }
}



function ToProcessorArchitectureConstant {
    param ($AssemblyInfo)

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "_M_IX86" }
        'Amd64'     { "_M_AMD64" }
        'MSIL'      { "_M_MSIL" }
        Default     { "_M_MSIL" }
    }
}



function ToTargetFrameworkVersionConstant {
    param ($TargetFrameworkVersion)
    
    switch ($TargetFrameworkVersion)
    {
        'v3.5'      { "_NET_3_5" }
        'v4.0'      { "_NET_4" }
        'v4.5'      { "_NET_4_5" }
        'v4.5.1'    { "_NET_4_5_1" }
        Default     { "_NET_4" }
    }
}



function ToDefineConstants {
    param ($AssemblyInfo, $TargetFrameworkVersion)
    $result = (ToProcessorArchitectureConstant $AssemblyInfo), (ToTargetFrameworkVersionConstant $TargetFrameworkVersion)
    $result -join ';'
}



function ToPlatformTarget {
    param ($AssemblyInfo)

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "x86" }
        'Amd64'     { "x64" }
        'MSIL'      { "AnyCPU" }
        Default     { "AnyCPU" }
    }
}



function ToProcessorArchitectureString {
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
        { $_.psobject.TypeNames -contains $AssemblyNameExTypeName } {  
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
        'X86'                           { "x86"; break }
        { $_ -match '(Amd64)|(x64)' }   { "AMD64"; break }
        { $_ -match 'AnyCPU\|true' }    { "x86"; break }
        { $_ -match '(MSIL)|(AnyCPU)' } { "MSIL"; break }
        Default                         { "MSIL"; break }
    }
}



function ToReferenceInclude {
    param ($refAsmInfos)
    
    foreach ($refAsmInfo in $refAsmInfos) {
        @"
        <Reference Include="$($refAsmInfo.GetName().Name)">
            <HintPath>$($refAsmInfo.Location)</HintPath>
        </Reference>
"@
    }
}



function StripGenericParameterCount {
    param ($Name)
    $Name -replace '`\d+', ''
}



function ToFullNameFromType {
    param ($Type)
    
    $defName = $Type.FullName
    
    if ($Type.IsGenericType -and !$Type.IsGenericTypeDefinition) {
        $defName = $Type.Namespace + "." + $Type.Name
    } elseif ($Type.ContainsGenericParameters) {
        $defName = $Type.Name
    } elseif ($Type.IsNested) {
        $defName = $Type.FullName -replace '\+', '.'
    }

    if ($Type.IsGenericType) {
        $defName = StripGenericParameterCount $defName
        $genericArgNames = @()
        foreach ($genericArg in $Type.GetGenericArguments()) {
            $genericArgNames += (ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }

    $defName
}



function ToClassNameFromType {
    param ($Type)
    $defName = $Type.Name
    if ($Type.IsGenericType) {
        $defName = StripGenericParameterCount $defName
        $genericArgNames = @()
        foreach ($genericArg in $Type.GetGenericArguments()) {
            $genericArgNames += (ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
}



function ToBaseNameFromType {
    param ($Type)
    $defName = $Type.Name
    if ($Type.IsGenericType) {
        $defName = StripGenericParameterCount $defName
    }
    $defName + "Base"
}



function ToClassNameFromStub {
    param ($Stub)
    $defName = $Stub.Alias
    if ($Stub.Target.IsGenericMethod) {
        $defName = StripGenericParameterCount $defName
        $genericArgNames = @()
        foreach ($genericArg in $Stub.Target.GetGenericArguments()) {
            $genericArgNames += (ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
}



function IsPublic {
    param ($Type)
    $targetType = $Type
    if ($Type.HasElementType) { 
        $targetType = $Type.GetElementType()
    }
    $targetType.IsPublic -or $targetType.IsNestedPublic
}



function IsSignaturePublic {
    param ($Stub)

    $result = $true
    
    $paramInfos = $Stub.Target.GetParameters()
    $result = $result -and !(0 -lt @($paramInfos | ? { !(IsPublic $_.ParameterType) }).Length)

    switch ($Stub.Target)
    {
        { $_ -is [System.Reflection.MethodInfo] } {
            [System.Reflection.MethodInfo]$methodInfo = $null
            $methodInfo = $Stub.Target
            $result = $result -and (IsPublic $methodInfo.ReturnType)
            break
        }
        { $_ -is [System.Reflection.ConstructorInfo] } {
            # nop
            break
        }
        Default {
            throw New-Object System.ArgumentException ('Parameter $Stub.Target({0}) is not supported.' -f $Stub.Target.GetType()) 
        }
    }
    $result
}



function GetDelegateParameters {
    param ($Delegate)
    $invokeInfo = $Delegate.GetMethod('Invoke')
    if ($null -ne $invokeInfo) {
        $invokeInfo.GetParameters()
    }
}



function GetDelegateReturnType {
    param ($Delegate)
    $invokeInfo = $Delegate.GetMethod('Invoke')
    if ($null -ne $invokeInfo) {
        $invokeInfo.ReturnType
    }
}



function DefineParameter {
    param ($ParameterInfo)
    $paramType = $ParameterInfo.ParameterType
    if ($paramType.HasElementType) {
        $elemType = $paramType.GetElementType()
        if ($paramType.IsByRef) {
            if (($ParameterInfo.Attributes -band [System.Reflection.ParameterAttributes]::Out) -ne 0) {
                "out $(ToFullNameFromType $elemType) $($ParameterInfo.Name)"
            } else {
                "ref $(ToFullNameFromType $elemType) $($ParameterInfo.Name)"
            }
        } else {
            "$(ToFullNameFromType $elemType)[] $($ParameterInfo.Name)"
        }
    } else {
        "$(ToFullNameFromType $paramType) $($ParameterInfo.Name)"
    }
}



function DefineAllParameters {
    param ($Stub)
    $paramInfos = GetDelegateParameters $Stub.IndirectionDelegate
    $paramNames = @()
    foreach ($paramInfo in $paramInfos) {
        $paramNames += DefineParameter $paramInfo
    }
    "($($paramNames -join ', '))"
}



function LoadParameter {
    param ($ParameterInfo)
    $paramType = $ParameterInfo.ParameterType
    if ($paramType.HasElementType) {
        $elemType = $paramType.GetElementType()
        if ($paramType.IsByRef) {
            if (($ParameterInfo.Attributes -band [System.Reflection.ParameterAttributes]::Out) -ne 0) {
                "out $($ParameterInfo.Name)"
            } else {
                "ref $($ParameterInfo.Name)"
            }
        } else {
            "$($ParameterInfo.Name)"
        }
    } else {
        "$($ParameterInfo.Name)"
    }
}



function LoadAllParameters {
    param ($Stub)
    $paramInfos = GetDelegateParameters $Stub.IndirectionDelegate
    $paramNames = @()
    foreach ($paramInfo in $paramInfos) {
        $paramNames += LoadParameter $paramInfo
    }
    $paramNames -join ', '
}



function Load1stParameter {
    param ($Stub)
    $paramInfos = GetDelegateParameters $Stub.IndirectionDelegate
    $paramNames = @()
    foreach ($paramInfo in $paramInfos) {
        $paramNames += LoadParameter $paramInfo
    }
    $paramNames[0]
}



function HasReturnType {
    param ($Stub)
    $retType = GetDelegateReturnType $Stub.IndirectionDelegate
    $retType -ne [void]
}



function ToGenericParameterConstraintClause {
    param ($GenericArgument)

    $names = New-Object 'System.Collections.Generic.List[string]'
    $gpa = $GenericArgument.GenericParameterAttributes
    [System.Reflection.GenericParameterAttributes]$constraints = 0
    $constraints = $gpa -band [System.Reflection.GenericParameterAttributes]::SpecialConstraintMask
    if (($constraints -band [System.Reflection.GenericParameterAttributes]::NotNullableValueTypeConstraint) -ne 0) {
        $names.Add('struct')
    }

    if (($constraints -band [System.Reflection.GenericParameterAttributes]::ReferenceTypeConstraint) -ne 0) {
        $names.Add('class')
    }

    $typeConstraints = $GenericArgument.GetGenericParameterConstraints()
    foreach ($typeConstraint in $typeConstraints) {
        $fullName = ToFullNameFromType $typeConstraint
        if ($fullName -ne 'System.ValueType') {
            $names.Add($fullName)
        }
    }

    if (($constraints -band [System.Reflection.GenericParameterAttributes]::DefaultConstructorConstraint) -ne 0 -and 
        ($constraints -band [System.Reflection.GenericParameterAttributes]::NotNullableValueTypeConstraint) -eq 0) {
        $names.Add('new()')
    }

    if ($names.Count -eq 0) {
        $null
    } else {
        "where $($GenericArgument.Name) : $($names -join ', ')"
    }
}



function ToGenericParameterConstraintsFromType {
    param ($Type)

    $constraintClauses = New-Object 'System.Collections.Generic.List[string]'
    if ($Type.IsGenericType) {
        foreach ($genericArg in $Type.GetGenericArguments())
        {
            $constraintClause = ToGenericParameterConstraintClause $genericArg
            if ($null -eq $constraintClause) { continue }

            $constraintClauses.Add($constraintClause)
        }
    }

    $constraintClauses -join ' '
}



function ToGenericParameterConstraintsFromStub {
    param ($Stub)

    $constraintClauses = New-Object 'System.Collections.Generic.List[string]'
    if ($Stub.Target.IsGenericMethod) {
        foreach ($genericArg in $Stub.Target.GetGenericArguments())
        {
            $constraintClause = ToGenericParameterConstraintClause $genericArg
            if ($null -eq $constraintClause) { continue }

            $constraintClauses.Add($constraintClause)
        }
    }

    $constraintClauses -join ' '
}





. $(Join-Path $here NuGet.Add-PrigAssembly.ps1)
. $(Join-Path $here NuGet.ConvertTo-PrigAssemblyName.ps1)
. $(Join-Path $here NuGet.Find-IndirectionTarget.ps1)
. $(Join-Path $here NuGet.Get-IndirectionStubSetting.ps1)
. $(Join-Path $here NuGet.Invoke-Prig.ps1)
. $(Join-Path $here NuGet.New-PrigCsproj.ps1)
. $(Join-Path $here NuGet.New-PrigProxiesCs.ps1)
. $(Join-Path $here NuGet.New-PrigStubsCs.ps1)
. $(Join-Path $here NuGet.New-PrigTokensCs.ps1)





Export-ModuleMember -Function *-* -Alias *
