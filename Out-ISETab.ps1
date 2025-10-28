
Function Out-ISETab {
    [CmdletBinding()]
    [alias('tab')]

    Param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,
        [Switch]$UseCurrentFile
    )

    Begin {

        Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"

        if ($UseCurrentFile) {
            Write-Verbose 'Using current file'
            $tab = $psISE.CurrentFile
        }
        else {
            #create a new file
            Write-Verbose 'Creating a new tab'
            $tab = $psISE.CurrentPowerShellTab.Files.Add()
        }

        $data = @()
    }
    Process {
        #add each piped object
        $data += $InputObject
    } #process

    End {
        #send the data to the ISE tab
        $tab.Editor.InsertText(($data | Out-String))
        Write-Verbose -Message "Ending $($MyInvocation.MyCommand)"
    }

} #end function

