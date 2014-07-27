# 
# File: NuGet.New-PrigProxiesCs.ps1
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



function New-PrigProxiesCs {
    param ($WorkDirectory, $AssemblyInfo, $Section, $TargetFrameworkVersion)

    $results = New-Object System.Collections.ArrayList
    
    foreach ($namespaceGrouped in $Section.GroupedStubs) {
        $dir = $namespaceGrouped.Key -replace '\.', '\'

        foreach ($declTypeGrouped in $namespaceGrouped) {
            if (!(IsPublic $declTypeGrouped.Key) -or $declTypeGrouped.Key.IsValueType) { continue }
            $hasAnyInstanceMember = $false
            $content = @"

using System.ComponentModel;
using System.Runtime.Serialization;
using Urasandesu.Prig.Framework;

namespace $(ConcatIfNonEmpty $namespaceGrouped.Key '.')Prig
{
    public class PProxy$(ToClassNameFromType $declTypeGrouped.Key) $(ToGenericParameterConstraintsFromType $declTypeGrouped.Key)
    {
        $(ToFullNameFromType $declTypeGrouped.Key) m_target;
        
        public PProxy$(StripGenericParameterCount $declTypeGrouped.Key.Name)()
        {
            m_target = ($(ToFullNameFromType $declTypeGrouped.Key))FormatterServices.GetUninitializedObject(typeof($(ToFullNameFromType $declTypeGrouped.Key)));
        }

"@ + $(foreach ($stub in $declTypeGrouped | ? { !$_.Target.IsStatic -and (IsSignaturePublic $_) -and ($_.Target -is [System.Reflection.MethodInfo]) }) {
        $hasAnyInstanceMember = $true
@"

        public zz$(ToClassNameFromStub $stub) $(ToClassNameFromStub $stub)() $(ToGenericParameterConstraintsFromStub $stub)
        {
            return new zz$(ToClassNameFromStub $stub)(m_target);
        }

        [EditorBrowsable(EditorBrowsableState.Never)]
        public class zz$(ToClassNameFromStub $stub) $(ToGenericParameterConstraintsFromStub $stub)
        {
            $(ToFullNameFromType $declTypeGrouped.Key) m_target;

            public zz$(StripGenericParameterCount $stub.Alias)($(ToFullNameFromType $declTypeGrouped.Key) target)
            {
                m_target = target;
            }

            class Original$(StripGenericParameterCount $stub.Alias)
            {
                public static $(ToClassNameFromType $stub.IndirectionDelegate) Body;
            }

            $(ToClassNameFromType $stub.IndirectionDelegate) m_body;
            public $(ToClassNameFromType $stub.IndirectionDelegate) Body
            {
                set
                {
                    P$(ToClassNameFromType $declTypeGrouped.Key).$(ToClassNameFromStub $stub)().Body = $(DefineAllParameters $stub) =>
                    {
                        if (object.ReferenceEquals($(Load1stParameter $stub), m_target))
                            $(if (HasReturnType $stub) { "return " })m_body($(LoadAllParameters $stub));
                        else
                            $(if (HasReturnType $stub) { "return " })IndirectionDelegates.ExecuteOriginalOfInstance$(ToClassNameFromType $stub.IndirectionDelegate)(ref Original$(StripGenericParameterCount $stub.Alias).Body, typeof($(ToFullNameFromType $declTypeGrouped.Key)), "$($stub.Target.Name)", $(LoadAllParameters $stub));
                    };
                    m_body = value;
                }
            }
        }
"@}) + @"


        public static implicit operator $(ToFullNameFromType $declTypeGrouped.Key)(PProxy$(ToClassNameFromType $declTypeGrouped.Key) @this)
        {
            return @this.m_target;
        }
    }
}
"@
            if (!$hasAnyInstanceMember) { continue }

            $result = 
                New-Object psobject | 
                    Add-Member NoteProperty 'Path' ([System.IO.Path]::Combine($WorkDirectory, "$(ConcatIfNonEmpty $dir '\')PProxy$($declTypeGrouped.Key.Name).cs")) -PassThru | 
                    Add-Member NoteProperty 'Content' $content -PassThru
            [Void]$results.Add($result)
        }
    }

    ,$results
}
