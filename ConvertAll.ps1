Function ConvertTo-Definition {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = 'Enter a string to convert')]
        [String]$Text
    )


    if ($host.name -match 'ISE') {
        Write-Verbose 'Getting aliases'
        $aliases = Get-Alias | Where-Object { $_.name -notmatch '\?|\%' }

        foreach ($alias in $aliases) {
            #Write-Verbose $alias.name
            #match any alias on a word boundary that doesn't start with a $
            if ($Text -match "(m?)(?<=\b)(?<!-|\$)$($alias.name)(?=\b)(?!-)") {
                Write-Verbose ('Replacing {0} with {1}' -f $alias.name, $alias.Definition)
                $Text = $Text -replace "(m?)(?<=\b)(?<!-|\$)$($alias.name)(?=\b)(?!-)", $alias.definition
            }
        } #foreach

        #handle special cases of ? and %
        if ($Text -match '\?') {
            Write-Verbose 'Replacing with Where-Object'
            $Text = $Text -replace '\?', 'Where-Object'
        }

        if ($Text -match '\%') {
            Write-Verbose 'Replacing with ForEach-Object'
            $Text = $Text -replace '\%', 'ForEach-Object'
        }

        #write the replacement string to the current file
        $psISE.CurrentFile.editor.insertText($Text)
        Write-Verbose $text
    } #if ISE
    else {
        Write-Warning 'You must be using the PowerShell ISE'
    }
} #end function
