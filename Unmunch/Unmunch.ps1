#Requires -Version 7.3

[CmdletBinding()]
param (
    [string]
    $DictionaryPath,
    [bool]
    $NoPFX = $false,
    [bool]
    $NoCross = $false,
    [bool]
    $Indented = $true,
    [string]
    $OutPath,
    [string]
    $BatchDirectory
)

Add-Type -AssemblyName $PSScriptRoot\HunspellWordForms.dll
Add-Type -AssemblyName $PSScriptRoot\WeCantSpell.Hunspell.dll

if (!($BatchDirectory -or $DictionaryPath))
{
    Write-Host "[!] -DictionaryPath or -BatchDirectory argument is required."
    exit
}

if ($BatchDirectory)
{
    $dics = Get-ChildItem -Path $BatchDirectory -Filter *.dic
    if (!($dics.Count -gt 0))
    {
        Write-Host "[!] Couldn't find any *.dic file in the directory passed in -BatchDirectory"
        exit
    }

    $outPathName = Join-Path -Path $BatchDirectory -ChildPath "json"
    if(!(Test-Path $outPathName))
    {
        $null = mkdir $outPathName
    }

    foreach ($dic in $dics)
    {
        $dict = [WordForms]::new($dic.FullName)
        $dicFname = Split-Path $dic.FullName -LeafBase
        $dict.SerializeToJson("$(Join-Path -Path $outPathName -ChildPath $dicFname)", $Indented, $NoPFX, $false, $NoCross)
        Write-Host "*** Unmunched $($dicFname).dic"
    }
}

elseif($DictionaryPath -and $OutPath)
{
    if (!(Test-Path -Path $DictionaryPath))
    {
        Write-Host "[!] $($DictionaryPath) doesn't exist."
        exit
    }
    $dict = [WordForms]::new($DictionaryPath)
    $dicFname = Split-Path $DictionaryPath -LeafBase
    $dict.SerializeToJson("$($OutPath)", $Indented, $NoPFX, $false, $NoCross)
    Write-Host "*** Unmunched $($dicFname).dic"
}

elseif($DictionaryPath)
{
    if (!(Test-Path -Path $DictionaryPath))
    {
        Write-Host "[!] $($DictionaryPath) doesn't exist."
        exit
    }
    $dict = [WordForms]::new($DictionaryPath)
    $dicFname = Split-Path $DictionaryPath -LeafBase
    $dict.SerializeToJson("$($dicFname)", $Indented, $NoPFX, $false, $NoCross)
    Write-Host "*** Unmunched $($dicFname).dic"
}
