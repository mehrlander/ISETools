Function Find-InFile {
    [CmdletBinding()]
    Param()

    Set-StrictMode -Version Latest

    Write-Verbose "Starting $($MyInvocation.MyCommand)"
    #verify we are in the ISE
    if ($host.name -match 'ISE') {

        $Title = 'Find in Files'

        #prompt for file types to search
        $Prompt = 'Enter a path and file types to search. Leave blank to cancel'
        $Default = '.\*.ps1'
        $path = New-InputBox -Prompt $prompt -Title $Title -Default $Default

        if ($path) {
            #prompt for what to search for
            $Prompt = 'What do you want to search for'
            $Default = $Null
            $find = New-InputBox -Prompt $prompt -Title $Title -Default $Default

            #execute search
            $results = Select-String -Pattern $find -Path $path |
            Select-Object Path, Filename,
            @{Name = 'Line'; Expression = { $_.Line.Trim() } }, LineNumber |
            Out-GridView -Title 'Select one or more matching files' -OutputMode Multiple

            #open files and jump to matching line
            foreach ($item in $results) {
                Write-Verbose ($item | Out-String)
                Open-EditorFile $item.path
                #give file a chance to open
                Start-Sleep -Milliseconds 100
                #get current files
                $f = $psISE.CurrentPowerShellTab.Files
                #select the last one
                $psISE.CurrentPowerShellTab.Files.SelectedFile = $f[-1]
                #set the cursor
                $psISE.CurrentPowerShellTab.files.SelectedFile.Editor.SetCaretPosition($item.LineNumber, 1)
            }
        }
    }
    else {
        Write-Warning 'This version only works in the PowerShell ISE'
    }
    Write-Verbose "Ending $($MyInvocation.MyCommand)"

}
