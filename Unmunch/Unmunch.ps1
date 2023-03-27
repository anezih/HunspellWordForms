#Requires -Version 7.3

[CmdletBinding()]
param (
    [string]$DictionaryPath,
    [switch]$NoPFX,
    [switch]$NoCross,
    [switch]$NoIndent,
    [string]$OutPath,
    [string]$BatchDirectory,
    [switch]$Gzip,
    [switch]$DeleteOriginalFile
)

Add-Type -AssemblyName $PSScriptRoot\HunspellWordForms.dll
Add-Type -AssemblyName $PSScriptRoot\WeCantSpell.Hunspell.dll

function gzip
{
    param
    (
        [string]$filePath,
        [bool]$deleteOriginalFile = $false
    )
    try
    {
        $filePath = $filePath + ".json"
        [System.IO.FileStream]$fs = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open)
        [System.IO.FileStream]$outFs = [System.IO.File]::Create("$($filePath).gz")
        [System.IO.Compression.GZipStream]$cfs = [System.IO.Compression.GZipStream]::new($outFs, [System.IO.Compression.CompressionLevel]::SmallestSize)
        $fs.CopyTo($cfs)
        Write-Host "+++ Compressed $(Split-Path $filePath -Leaf) to gzip format."
    }
    catch
    {
        <#Do this if a terminating exception happens#>
    }
    finally
    {
        $cfs.Dispose() ; $outFs.Dispose() ; $fs.Dispose()
        if ($deleteOriginalFile)
        {
            Remove-Item -Path $filePath
            Write-Host "--- Deleted $(Split-Path $filePath -Leaf)."
        }
    }
}

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
        $outFname = "$(Join-Path -Path $outPathName -ChildPath $dicFname)"
        $dict.SerializeToJson($outFname, !$NoIndent, $NoPFX, $false, $NoCross)
        Write-Host "*** Unmunched $($dicFname).dic"

        if ($Gzip)
        {
            gzip -filePath $outFname -deleteOriginalFile:$DeleteOriginalFile
        }
        Write-Host ""
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
    $dict.SerializeToJson("$($OutPath)", !$NoIndent, $NoPFX, $false, $NoCross)
    Write-Host "*** Unmunched $($dicFname).dic"

    if ($Gzip)
    {
        gzip -filePath $OutPath -deleteOriginalFile:$DeleteOriginalFile
    }
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
    $dict.SerializeToJson("$($dicFname)", !$NoIndent, $NoPFX, $false, $NoCross)
    Write-Host "*** Unmunched $($dicFname).dic"

    if ($Gzip)
    {
        gzip -filePath $dicFname -deleteOriginalFile:$DeleteOriginalFile
    }
}
