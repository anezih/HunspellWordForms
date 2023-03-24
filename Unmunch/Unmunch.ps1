#Requires -Version 7

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $DictionaryPath,
    [bool]
    $NoPFX = $false,
    [bool]
    $NoCross = $false,
    [bool]
    $Indented = $true,
    [string]
    $OutPath
)

Add-Type -AssemblyName $PSScriptRoot\HunspellWordForms.dll
# Put WeCantSpell.Hunspell.dll in the same directory with the dll above.

$dict = [WordForms]::new($DictionaryPath)

if($OutPath)
{
    $dict.SerializeToJson("$($OutPath)", $Indented, $NoPFX, $false, $NoCross)
}
else 
{
    $dict.SerializeToJson("unmunched", $Indented, $NoPFX, $false, $NoCross)
}