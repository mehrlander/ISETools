Function ConvertTo-TextFile {
    [CmdletBinding()]
    Param (
        [Switch]$Reload
    )

    #verify we are in the ISE
    if ($psISE) {
        #get the current file name and path and change the extension
        $PSVersion = $psISE.CurrentFile.FullPath
        $textVersion = $PSVersion -replace 'ps1', 'txt'

        #save the file.
        $psISE.CurrentFile.SaveAs($textVersion)

        #if -Reload then reload the PowerShell file into the ISE
        if ($Reload) {
            $psISE.CurrentPowerShellTab.Files.Add($PSVersion)
        }
    } #if $psISE
    else {
        Write-Warning 'This function requires the Windows PowerShell ISE.'
    }
} #end function
