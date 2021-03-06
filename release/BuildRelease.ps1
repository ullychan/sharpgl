# IMPORTANT: Make sure that the path to msbuild is correct!  
$msbuild = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe"
if ((Test-Path $msbuild) -eq $false) {
    Write-Host "Cannot find msbuild at '$msbuild'."
    Break
}

# Load useful functions.
. .\Resources\PowershellFunctions.ps1

# Keep track of the 'release' folder location - it's the root of everything else.
# We can also build paths to the key locations we'll use.
$scriptParentPath = Split-Path -parent $MyInvocation.MyCommand.Definition
$folderReleaseRoot = $scriptParentPath
$folderSourceRoot = Split-Path -parent $folderReleaseRoot
$folderSharpGLRoot = Join-Path $folderSourceRoot "source\SharpGL"
$folderNuspecRoot = Join-Path $folderSourceRoot "release\Specs"

# Part 1 - Build the core libraries.
Write-Host "Preparing to build the core libraries..."
$solutionCoreLibraries = Join-Path $folderSharpGLRoot "SharpGL.sln"
. $msbuild $solutionCoreLibraries /p:Configuration=Release /verbosity:minimal

# Part 2 - Get the version number of the SharpGL core library, use this to build the destination release folder.
$folderBinariesSharpGL = Join-Path $folderSharpGLRoot "Core\SharpGL\bin\Release"
$folderBinariesSharpGLSceneGraph = Join-Path $folderSharpGLRoot "Core\SharpGL.SceneGraph\bin\Release"
$folderBinariesSharpGLSerialization = Join-Path $folderSharpGLRoot "Core\SharpGL.Serialization\bin\Release"
$folderBinariesSharpGLWinForms = Join-Path $folderSharpGLRoot "Core\SharpGL.WinForms\bin\Release"
$folderBinariesSharpGLWPF = Join-Path $folderSharpGLRoot "Core\SharpGL.WPF\bin\Release"
$releaseVersion = [Reflection.Assembly]::LoadFile((Join-Path $folderBinariesSharpGL "SharpGL.dll")).GetName().Version.ToString()
Write-Host "Built Core Libraries. Release Version: $releaseVersion"

# Part 3 - Copy the core libraries to the release.
$folderRelease = Join-Path $folderReleaseRoot $releaseVersion
$folderReleaseCore = Join-Path $folderRelease "Core"
EnsureEmptyFolderExists($folderReleaseCore)
CopyItems (Join-Path $folderBinariesSharpGL "*.*") (Join-Path $folderReleaseCore "SharpGL")
CopyItems (Join-Path $folderBinariesSharpGLSceneGraph "*.*") (Join-Path $folderReleaseCore "SharpGL.SceneGraph")
CopyItems (Join-Path $folderBinariesSharpGLSerialization "*.*") (Join-Path $folderReleaseCore "SharpGL.Serialization")
CopyItems (Join-Path $folderBinariesSharpGLWinForms "*.*") (Join-Path $folderReleaseCore "SharpGL.WinForms")
CopyItems (Join-Path $folderBinariesSharpGLWPF "*.*") (Join-Path $folderReleaseCore "SharpGL.WPF")

# Part 4 - Build the Samples
Write-Host "Preparing to build the samples..."
$solutionSamples = Join-Path $folderSharpGLRoot "Samples.sln"
. $msbuild $solutionSamples /p:Configuration=Release /verbosity:quiet

# Part 5 - Copy the samples to the release.
$folderReleaseSamples = Join-Path $folderRelease "Samples"
EnsureEmptyFolderExists($folderReleaseSamples)
$releaseFolders = gci (Join-Path $folderSharpGLRoot "Samples") -Recurse -Directory -filter "Release" | select FullName
$releaseFolders | ForEach {
    $releaseFolder = $_.FullName
    if ((GetParentFolderName $releaseFolder) -eq "bin") {
        $sampleName = (Get-Item (Split-Path -parent (Split-Path -parent $releaseFolder))).Name
        Write-Host "Built Sample: $sampleName"

        # Make sure the destination directory exists, copy the files over.
        $destinationFolder = (Join-Path $folderReleaseSamples "$sampleName")
        EnsureFolderExists $destinationFolder    
        Get-ChildItem $releaseFolder -Recurse -Exclude '*.pdb*', '*.xml*' | Copy-Item -Destination $destinationFolder
    }
}
Write-Host "Built samples."

# Part 6 - Build the Tools
Write-Host "Preparing to build the tools..."
$solutionTools = Join-Path $folderSharpGLRoot "Tools.sln"
. $msbuild $solutionTools /p:Configuration=Release /verbosity:quiet

# Part 7 - Copy the tools to the release.
$folderReleaseTools = Join-Path $folderRelease "Tools"
EnsureEmptyFolderExists($folderReleaseTools)
$releaseFolders = gci (Join-Path $folderSharpGLRoot "Tools") -Recurse -Directory -filter "Release" | select FullName
$releaseFolders | ForEach {
    $releaseFolder = $_.FullName
    if ((GetParentFolderName $releaseFolder) -eq "bin") {
        $toolName = (Get-Item (Split-Path -parent (Split-Path -parent $releaseFolder))).Name
        Write-Host "Built Tool: $toolName"

        # Make sure the destination directory exists, copy the files over.
        $destinationFolder = (Join-Path $folderReleaseTools "$toolName")
        EnsureFolderExists $destinationFolder    
        Get-ChildItem $releaseFolder -Recurse -Exclude '*.pdb*' | Copy-Item -Destination $destinationFolder
    }
}
Write-Host "Built tools."

# Part 8 - Build the Nuget Packages
Write-Host "Preparing to build the Nuget Packages..."
$folderReleasePackages = Join-Path $folderRelease "Packages"
EnsureEmptyFolderExists($folderReleasePackages)
$nuget = Join-Path $scriptParentPath "Resources\nuget.exe"

CreateNugetPackage $nuget (Join-Path $folderNuspecRoot "SharpGL.nuspec") $releaseVersion @{} (Join-Path $folderReleaseCore "SharpGL.SceneGraph\*.*") $folderReleasePackages
CreateNugetPackage $nuget (Join-Path $folderNuspecRoot "SharpGL.WinForms.nuspec") $releaseVersion @{"SharpGL"=$releaseVersion} (Join-Path $folderReleaseCore "SharpGL.WinForms\SharpGL.WinForms.*") $folderReleasePackages
CreateNugetPackage $nuget (Join-Path $folderNuspecRoot "SharpGL.WPF.nuspec") $releaseVersion @{"SharpGL"=$releaseVersion} (Join-Path $folderReleaseCore "SharpGL.WPF\SharpGL.WPF.*") $folderReleasePackages

# We're done!
Write-Host "Successfully built version: $releaseVersion"