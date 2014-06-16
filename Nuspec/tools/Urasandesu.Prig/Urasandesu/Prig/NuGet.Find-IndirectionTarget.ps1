# 
# File: NuGet.Find-IndirectionTarget.ps1
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

function Find-IndirectionTarget {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $Type, 
    
        [Parameter(Position = 1)]
        $Method 
    )

    $typeInfo = $Type
    if ($typeInfo -is [string]) {
        $typeInfo = $(try { Invoke-Expression $Type } catch { })
        if ($null -eq $typeInfo) {
            $typeInfo = $(try { Invoke-Expression ('[{0}]' -f $Type) } catch { })
        }
    }
    if ($typeInfo -isnot [type]) {
        throw New-Object System.ArgumentException '-Type option must be a type or a string that can parse to a type(e.g. -Type ([datetime]) or -Type datetime).'
    }

    $methodInfos = $typeInfo.GetMethods(([System.Reflection.BindingFlags]'Public, NonPublic, Static, Instance'))
    if ($null -ne $Method) {
        foreach ($methodInfo in $methodInfos) {
            if ($methodInfo.ToString() -match $Method) {
                $methodInfo
            }
        }
    } else {
        $methodInfos
    }
}

New-Alias PFind Find-IndirectionTarget
