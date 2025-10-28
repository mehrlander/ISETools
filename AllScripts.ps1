Function Get-ISEBookmark {
    [CmdletBinding()]
    Param()

    Try {
        Import-Csv $MyBookmarks -ErrorAction Stop |
        Out-GridView -Title 'My ISE Bookmarks' -OutputMode Single
    }
    Catch {
        Write-Warning "Failed to find or import bookmarks from $($MyBookmarks). Does file exist?"
    }
}

Function Open-ISEBookmark {
    [CmdletBinding()]
    Param()

    $bookmark = Get-ISEBookmark

    if ($bookmark) {

        Open-EditorFile $bookmark.path

        $search = $psISE.CurrentPowerShellTab.files.where( { $_.FullPath -eq $bookmark.path })

        $psISE.CurrentPowerShellTab.files.SelectedFile = $search[0]

        $search[0].editor.SetCaretPosition($bookmark.LineNumber, 1)
    }

}

Function Remove-ISEBookmark {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    $bookmark = Get-ISEBookmark

    if ($bookmark) {
        $save = Import-Csv -Path $MyBookmarks | Where-Object { $_.id -notmatch $bookmark.id }
        $save | Export-Csv -Path $MyBookmarks -Encoding ASCII

    }

}

Function Update-ISEBookmark {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$Bookmark
    )

    $bookmark = Get-ISEBookmark

    if ($bookmark) {
        $line = New-Inputbox -Prompt 'Enter the line number' -Title $MyInvocation.MyCommand -Default $Bookmark.LineNumber
        if ($line) {
            $name = New-Inputbox -Prompt 'Enter the name' -Title $MyInvocation.MyCommand -Default $Bookmark.name
        }
        else {
            Return
        }

        If ($name) {

            $all = Get-Content -Path $MyBookmarks | ConvertFrom-Csv

            $bmk = $all.where( { $_.id -eq $bookmark.id })

            $bmk[0].LineNumber = $line
            $bmk[0].name = $name

            $all | Export-Csv -Path $MyBookmarks
        }
        else {
        }
    }

}

Function Add-ISEBookmark {

    $line = $psISE.CurrentFile.Editor.CaretLine
    $path = $psISE.CurrentFile.FullPath
    $name = New-Inputbox -Prompt 'Enter a name or description for this bookmark.' -Title 'Add ISE Bookmark'

    $obj = [PSCustomObject]@{
        ID         = [guid]::NewGuid().guid
        LineNumber = $line
        Name       = $name
        Path       = $Path
    }
    $obj | Export-Csv -Path $MyBookmarks -Append -Encoding ASCII

}

Function New-CIMCommand {
    Param([String]$computername = $env:COMPUTERNAME)

    Function Get-Namespace {

        Param(
            [String]$Namespace = 'Root',
            [Microsoft.Management.Infrastructure.CimSession]$CimSession
        )

        $nSpaces = $CimSession | Get-CimInstance -Namespace $Namespace -ClassName __Namespace
        foreach ($nSpace in $nSpaces) {

            $child = Join-Path -Path $Namespace -ChildPath $nspace.Name
            $child
            Get-Namespace $child $CimSession
        }
    }

    $cimSess = New-CimSession -ComputerName $computername

    Write-Host "Enumerating namespaces on $computername....please wait..." -ForegroundColor Cyan
    $ns = Get-Namespace -CimSession $cimsess | Sort-Object |
    Out-GridView -Title "$($cimsess.Computername): Select a namespace" -OutputMode Single

    if ($ns) {
        Write-Host 'Enumerating classes...please wait...' -ForegroundColor Cyan
        $class = $cimsess | Get-CimClass -Namespace $ns |
        Where-Object { $_.cimClassName -notmatch '^__' -AND $_.CimClassProperties.Name -notcontains 'Antecedent' } |
        Sort-Object CimClassName | Select-Object CimClassName, CimClassProperties |
        Out-GridView -Title "$NS : Select a class name" -OutputMode Single
    }

    if ($class) {

        $wshell = New-Object -ComObject 'Wscript.Shell'
        $r = $wshell.Popup('Do you want to test this class?', -1, $class.CimClassName, 32 + 4)

        if ($r -eq 6) {
            $test = $cimsess | Get-CimInstance -Namespace $ns -ClassName $class.CimClassName
            if ($test) {
                $test | Out-GridView -Title "$NS\$($Class.cimClassName)" -Wait
                $prompt = 'Do you want to continue?'
                $icon = 32 + 4
            }
            else {
                $prompt = 'No results were returned. Do you want to continue?'
                $icon = 16 + 4
            }

            $r = $wshell.Popup($prompt, -1, $class.CimClassName, $icon)
            if ($r -eq 7) {
                Write-Host 'Exiting. Please try again later.' -ForegroundColor Yellow
                Return
            }

        }

        $cmd = 'Get-CimInstance @cimParam'

        $FilterProperty = $class.CimClassProperties | Select-Object Name, CimType, Flags |
        Out-GridView -Title 'Select a property to filter on or cancel to not filter.' -OutputMode Single

        if ($FilterProperty) {
            $operator = '=', '<', '>', '<>', '>=', '<=', 'like' |
            Out-GridView -Title 'Select an operator. Default if you cancel is =' -OutputMode Single

            Add-Type -AssemblyName 'Microsoft.VisualBasic' -ErrorAction Stop
            $Prompt = "Enter a value for your filter. If using a string, wrap the value in ''. If using Like, use % as the wildcard character."
            $title = "-filter ""$($FilterProperty.Name) $operator ?"""
            $value = [Microsoft.VisualBasic.interaction]::InputBox($Prompt, $Title)

            $filter = "-filter ""$($FilterProperty.Name) $operator $value"""

            $cmd += " $filter"
        }

        Write-Host 'Getting class properties' -ForegroundColor Cyan
        $properties = $class.CimClassProperties | Select-Object Name, CimType, Flags |
        Out-GridView -Title "$($class.CimClassName) : Select one or more properties. Cancel will select *" -PassThru

        if ($properties) {
            $select = $properties.name -join ','
            $cmd += @"
 |
    Select-Object -property $select,PSComputername
"@
        }

    }

    $cname = $class.CimClassName.Replace('_', '')
    $cmdName = "Get-$cname"

    $myScript = @"

Function $cmdName  {

[CmdletBinding(DefaultParameterSetName="Computer")]
Param(
[Parameter(Position=0,ValueFromPipelineByPropertyName=`$True,
ParameterSetName="Computer")]
[ValidateNotNullOrEmpty()]
[Alias("CN","Host")]
[string[]]`$Computername=`$env:Computername,

[Parameter(Position=0,ValueFromPipeline=`$True,
ParameterSetName="Session")]
[string[]]`$CimSession

)

Begin {
    `$cimParam=@{
    Namespace = "$NS"
    ClassName = "$($Class.CimClassName) "
    ErrorAction = "Stop"
    }
}

Process {
    if (`$computername) {
    `$cimParam.Computername=`$computername
    }
    else {
    `$cimParam.CimSession=`$CimSession
    }

    Try {
        $cmd
    }
    Catch {
        Write-Warning "Failed to retrieve information. `$(`$_.Exception.Message)"
    }
}

End {
}

}
"@

    $myScript | Out-ISETab

    $cimsess | Remove-CimSession

}

Function CloseAllFiles {
    [CmdletBinding()]
    Param()

    $saved = $psISE.CurrentPowerShellTab.Files.Where( { $_.isSaved })
    foreach ($file in $saved) {
        [void]$psISE.CurrentPowerShellTab.files.Remove($file)
    }

}

Function CloseAllFilesButCurrent {
    [CmdletBinding()]
    Param()

    $saved = $psISE.CurrentPowerShellTab.Files.Where( { $_.isSaved -AND $_.FullPath -ne $psISE.CurrentFile.FullPath })
    foreach ($file in $saved) {
        [void]$psISE.CurrentPowerShellTab.files.Remove($file)
    }

}

Function Convert-AliasDefinition {
    [CmdletBinding(DefaultParameterSetName = 'ToDefinition')]

    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = 'Enter a string to convert')]
        [String]$Text,
        [Parameter(ParameterSetName = 'ToAlias')]
        [Switch]$ToAlias,
        [Parameter(ParameterSetName = 'ToDefinition')]
        [Switch]$ToDefinition
    )

    if ($host.name -match 'ISE') {
        Try {
            if ($ToAlias) {
                $alias = Get-Alias -Definition $Text -ErrorAction Stop
                if ($alias -is [array]) {
                    $replace = $alias[0].name
                }
                else {
                    $replace = $alias.name
                }
            }
            else {

                if ($Text -eq '?') {
                    $Replace = 'Where-Object'
                }
                else {
                    $alias = Get-Alias -Name $Text -ErrorAction Stop
                    $replace = $alias.definition
                }
            }

        }

        Catch {
            Write-Host "Nothing for for $text" -ForegroundColor Cyan
        }

        If ($replace) {
            $psISE.CurrentFile.editor.insertText($replace)
        }

    }
    else {
        Write-Warning 'You must be using the PowerShell ISE'
    }

}

Function Convert-CodeToSnippet {
    [CmdletBinding(SupportsShouldProcess)]
    [alias('ccs')]

    Param(
        [Parameter(Position = 0, Mandatory,
            HelpMessage = 'Enter some code text or break, select text in the ISE and try again.')]
        [ValidateNotNullOrEmpty()]
        [String]$Text
    )

    Add-Type -AssemblyName 'Microsoft.VisualBasic'

    $title = [Microsoft.VisualBasic.Interaction]::InputBox('Enter a title for your snippet', $MyInvocation.MyCommand.name)

    if ($title) {
        $description = [Microsoft.VisualBasic.Interaction]::InputBox('Enter a description for your snippet', $MyInvocation.MyCommand.name, 'This is required')
        if ($description) {
            $author = [Microsoft.VisualBasic.Interaction]::InputBox('Enter an author for your snippet', $MyInvocation.MyCommand.name, $env:username)
            if (!$author) {
                $author = ' '
            }
        }
        else {
            Write-Warning -Message 'No description was specified. Operation cancelled.'
            Return
        }

        if ($PSCmdlet.ShouldProcess($title) ) {
            Try {
                New-IseSnippet -Title $title -Text $Text -description $Description -author $Author
            }
            Catch {
                $message = ("There was an error creating the snippet. `n`n{0} `n`nDo you want to force an overwrite?" -f $_.exception.message)
                $returnValue = [Microsoft.VisualBasic.interaction]::MsgBox($message, 'YesNo,Exclamation', $MyInvocation.MyCommand.name)
                if ($returnValue -eq 'yes') {
                    New-IseSnippet -Title $title -Text $Text -description $Description -author $Author -Force
                }
            }
        }
    }

}

Function Convert-CommandToHash {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Text = $psISE.CurrentFile.editor.SelectedText
    )

    Set-StrictMode -Version latest

    New-Variable $AstTokens -Force
    New-Variable astErr -Force


    $AST = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$AstTokens, [ref]$astErr)

    $cmdType = Get-Command $AstTokens[0].text
    if ($cmdType.CommandType -eq 'Alias') {
        $cmd = $cmdType.ResolvedCommandName
    }
    else {
        $cmd = $cmdType.Name
    }


    $r = for ($i = 1; $i -lt $AstTokens.count - 2 ; $i++) {
        if ($AstTokens[$i].ParameterName) {
            $p = $AstTokens[$i].ParameterName
            $v = ''
            if ($AstTokens[$i + 1].Kind -match 'Parameter|NewLine|EndOfInput') {
                $v = "`$True"
            }
            else {
                While ($AstTokens[$i + 1].Kind -notmatch 'Parameter|NewLine|EndOfInput') {
                    $i++
                    if ($AstTokens[$i].Text -match '\D' -AND $AstTokens[$i].Text -notmatch '"\w+.*"' -AND $AstTokens[$i].Text -notmatch "'\w+.*'") {
                        if ($AstTokens[$i].Kind -match 'Comma|Variable') {
                            $value = $AstTokens[$i].Text
                        }
                        else {
                            $value = "'$($AstTokens[$i].Text)'"
                        }
                    }
                    else {
                        $value = $AstTokens[$i].Text
                    }

                    $v += $value
                }
            }

            "$p = $v`r"
        }

    }


    $HashText = @"
`$paramHash = @{
 $r}

$cmd @paramHash
"@

    $psISE.CurrentFile.Editor.InsertText($HashText)

}

Function ConvertTo-MultiLineComment {
    [CmdletBinding()]
    Param([String]$Text = $psISE.CurrentFile.Editor.SelectedText)

    if ($text -match '^$') {
        Write-Warning 'Selected text already appears to be a multiline comment'
    }
    elseif ($text -match '^#') {
        $text = $text.Replace('#', '')
        $replace = ""

    }
    else {
        $replace = @"

"@

    }

    if ($replace) {
        $psISE.CurrentFile.editor.InsertText($replace)
    }
}

Function ConvertFrom-MultiLineComment {
    [CmdletBinding()]
    Param([String]$Text = $psISE.CurrentFile.Editor.SelectedText)

    $MyText = $Text.Trim()

    if ($MyText.StartsWith('')) {
        $replace = $myText.Substring(2, $MyText.length - 4)

        [string[]]$newText = $replace.split("`n") |
        Select-Object -Skip 1 -First ($MyText.Split("`n").count - 2) | ForEach-Object { ("#$_").Trim() }
        $psISE.CurrentFile.editor.InsertText(($newText.trim() | Out-String))
    }
    else {
        Write-Warning 'Could not detect that selected text is a multiline comment'
    }

}

Function ConvertTo-Definition {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = 'Enter a string to convert')]
        [String]$Text
    )

    if ($host.name -match 'ISE') {
        $aliases = Get-Alias | Where-Object { $_.name -notmatch '\?|\%' }

        foreach ($alias in $aliases) {
            if ($Text -match "(m?)(?<=\b)(?<!-|\$)$($alias.name)(?=\b)(?!-)") {
                $Text = $Text -replace "(m?)(?<=\b)(?<!-|\$)$($alias.name)(?=\b)(?!-)", $alias.definition
            }
        }

        if ($Text -match '\?') {
            $Text = $Text -replace '\?', 'Where-Object'
        }

        if ($Text -match '\%') {
            $Text = $Text -replace '\%', 'ForEach-Object'
        }

        $psISE.CurrentFile.editor.insertText($Text)
    }
    else {
        Write-Warning 'You must be using the PowerShell ISE'
    }
}

Function ConvertFrom-Alias {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        $Text = $psISE.CurrentFile.Editor.text
    )

    if ($host.name -match 'ISE') {


        $out = $null
        $tokens = [System.Management.Automation.PSparser]::Tokenize($text, [ref]$out)

        if ($out) {
            foreach ($problem in $out) {
                Write-Warning $problem.message
                Write-Warning "Line: $($problem.Token.StartLine) at character: $($problem.token.StartColumn)"
            }
        }
        else {
            $tokens | Where-Object { $_.Type -eq 'Command' } |
            Sort-Object StartLine, StartColumn -Descending |
            ForEach-Object {
                if ($_.content -eq '?') {
                    $result = Get-Command -Name '`?' -CommandType Alias
                }
                else {
                    $result = Get-Command -Name $_.Content -CommandType Alias -ErrorAction SilentlyContinue
                }

                if ($result) {
                    $psISE.CurrentFile.Editor.Select($_.StartLine, $_.StartColumn, $_.EndLine, $_.EndColumn)
                    $psISE.CurrentFile.Editor.InsertText($result.Definition)
                }
            }
        }
    }
    else {
        Write-Warning 'You must be using the PowerShell ISE'
    }


}

Function ConvertTo-CommentHelp {
    [CmdletBinding()]
    Param()

    Add-Type -AssemblyName 'Microsoft.VisualBasic' -ErrorAction Stop
    $Prompt = 'Enter the name of a cmdlet. Leave blank to cancel'
    $Default = ''
    $Title = $MyInvocation.MyCommand.Name
    [String]$command = [Microsoft.VisualBasic.interaction]::InputBox($Prompt, $Title, $Default)

    if ($command) {
        Try {

            $help = Get-Help -Name $command -Full -ErrorAction Stop
        }
        Catch {
            Throw $_
            Return
        }
    }
    Else {
    }

    If ($help) {
        $myHelp = @"

"@

        $myHelp | Out-ISETab
    }

}

Function ConvertTo-TextFile {
    [CmdletBinding()]
    Param (
        [Switch]$Reload
    )

    if ($psISE) {
        $PSVersion = $psISE.CurrentFile.FullPath
        $textVersion = $PSVersion -replace 'ps1', 'txt'

        $psISE.CurrentFile.SaveAs($textVersion)

        if ($Reload) {
            $psISE.CurrentPowerShellTab.Files.Add($PSVersion)
        }
    }
    else {
        Write-Warning 'This function requires the Windows PowerShell ISE.'
    }
}

Function Copy-ToWord {
    [CmdletBinding()]
    Param(
        [ValidatePattern("\S+")]
        [string[]]$Text = $psISE.CurrentFile.Editor.SelectedText,
        [Switch]$Colorized
    )

    If (($null -eq $global:word.Application) -OR -NOT (Get-Process WinWord)) {
        Remove-Variable -Name doc, selection -Force -ErrorAction SilentlyContinue

        $global:word = New-Object -ComObject word.application

        $global:doc = $global:word.Documents.add()

        $global:selection = $global:word.Selection

        $global:selection.Font.Name = "Consolas"
        $global:selection.font.Size = 10
        $global:selection.paragraphFormat.SpaceBefore = 0
        $global:selection.paragraphFormat.SpaceAfter = 0

        $global:word.Visible = $True
    }

    if ($Colorized) {
        $wshell = New-Object -ComObject Wscript.shell
        $wshell.SendKeys("^c")
        start-sleep -Milliseconds 500
        $global:selection.Paste()
    }
    else {
        $global:selection.TypeText($text)
    }

    $global:selection.TypeParagraph()

}

Function Add-CurrentProject {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$List = $currentProjectList
    )

    If ((Get-Content -Path $CurrentProjectList) -NotContains $psISE.CurrentFile.FullPath) {
        $psISE.CurrentFile.FullPath | Out-File -FilePath $list -Encoding ascii -Append
    }
    else {
        Write-Warning "$($psISE.CurrentFile.FullPath) already in $list"

    }
}

Function Edit-CurrentProject {

    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateScript( {
                if (Test-Path $_) {
                    $True
                }
                else {
                    Throw "Cannot validate path $_"
                }
            })]
        [String]$List
    )

    Open-EditorFile $list

}

Function Import-CurrentProject {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateScript( {
                if (Test-Path $_) {
                    $True
                }
                else {
                    Throw "Cannot validate path $_"
                }
            })]
        [String]$List
    )

    $items = Get-Content -Path $list | Where-Object { $_ }

    foreach ($item in $items) {
        if (Test-Path $item) {
            Open-EditorFile $item
        }
        else {
            Write-Warning "Can't find $item"
        }
    }

}

Function Get-NextISETab {
    [CmdletBinding()]
    Param()

    $iseTabs = $psISE.PowerShellTabs

    for ($i = 0; $i -le $iseTabs.count - 1; $i++) {
        if ($iseTabs[$i].DisplayName -eq $psISE.CurrentPowerShellTab.DisplayName) {
            $current = $i
        }
    }

    if ($current++ -ge $iseTabs.count - 1) {
        $next = 0
    }
    else {
        $next = $current++
    }

    $nextTab = $iseTabs[$next]

    $iseTabs.SelectedPowerShellTab = $NextTab

}

Function Edit-Snippet {
    Param(
        [String]$Path = "$env:userprofile\Documents\WindowsPowerShell\Snippets"
    )

    $snips = Get-ChildItem $path | Select-Object @{Name = 'Name'; Expression = { $_.name.split('.')[0] } } |
    Out-GridView -Title 'Select one or more snippets to edit' -OutputMode Multiple

    foreach ($snip in $snips) {
        $file = Join-Path -Path $path -ChildPath "$($snip.name).snippets.ps1xml"
        Open-EditorFile $file
    }

}

Function Find-InFile {
    [CmdletBinding()]
    Param()

    Set-StrictMode -Version Latest

    if ($host.name -match 'ISE') {

        $Title = 'Find in Files'

        $Prompt = 'Enter a path and file types to search. Leave blank to cancel'
        $Default = '.\*.ps1'
        $path = New-InputBox -Prompt $prompt -Title $Title -Default $Default

        if ($path) {
            $Prompt = 'What do you want to search for'
            $Default = $Null
            $find = New-InputBox -Prompt $prompt -Title $Title -Default $Default

            $results = Select-String -Pattern $find -Path $path |
            Select-Object Path, Filename,
            @{Name = 'Line'; Expression = { $_.Line.Trim() } }, LineNumber |
            Out-GridView -Title 'Select one or more matching files' -OutputMode Multiple

            foreach ($item in $results) {
                Open-EditorFile $item.path
                Start-Sleep -Milliseconds 100
                $f = $psISE.CurrentPowerShellTab.Files
                $psISE.CurrentPowerShellTab.Files.SelectedFile = $f[-1]
                $psISE.CurrentPowerShellTab.files.SelectedFile.Editor.SetCaretPosition($item.LineNumber, 1)
            }
        }
    }
    else {
        Write-Warning 'This version only works in the PowerShell ISE'
    }

}

Function Get-ASTProfile {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, HelpMessage = "Enter the path of a PowerShell script")]
        [ValidateScript( {Test-Path $_})]
        [ValidatePattern( "\.(ps1|psm1|txt)$")]
        [String]$Path = $(Read-Host "Enter the filename and path to a PowerShell script"),
        [ValidateScript( {Test-Path $_})]
        [Alias("fp", "out")]
        [String]$FilePath = "$env:userprofile\Documents\WindowsPowerShell"
    )


    $Path = (Resolve-Path -Path $Path).Path | Convert-Path
    New-Variable $AstTokens -force
    New-Variable astErr -force

    $AST = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$AstTokens, [ref]$astErr)


    if ($AST.ScriptRequirements) {
        $requirements = ($AST.ScriptRequirements | Out-String).Trim()
    }
    else {
        $requirements = "-->None detected"
    }

    if ($AST.ParamBlock.Parameters ) {
        $FoundParams = $(($AST.ParamBlock.Parameters |
                    Select-Object Name, DefaultValue, StaticType, Attributes |
                    Format-List | Out-String).Trim()
        )
    }
    else {
        $FoundParams = "-->None detected. Parameters for nested commands not tested."
    }

    $report = @"
This is an analysis of a PowerShell script or module. Analysis will most likely NOT be 100% thorough.

"@

    $report += @"

REQUIREMENTS
$requirements

PARAMETERS
$FoundParams

"@


    $commands = @()
    $unresolved = @()

    $genericCommands = $AstTokens |
        Where-Object {$_.TokenFlags -eq 'commandname' -AND $_.kind -eq 'generic'}

    $aliases = $AstTokens |
        Where-Object {$_.TokenFlags -eq 'commandname' -AND $_.kind -eq 'identifier'}

    foreach ($command in $genericCommands) {
        Try {
            $commands += Get-Command -Name $command.text -ErrorAction Stop
        }
        Catch {
            $unresolved += $command.Text
        }
    }

    foreach ($command in $aliases) {
        Try {
            $commands += Get-Command -Name $command.text -ErrorAction Stop |
                ForEach-Object {
                Get-Command -Name $_.Definition
            }
        }
        Catch {
            $unresolved += $command.Text
        }
    }

    $report += @"

ALL COMMANDS
All possible PowerShell commands. This list may not be complete or even correct.

$(($Commands | Sort-Object -Unique | Format-Table -AutoSize | Out-String).Trim())

"@

    if ($unresolved) {
        $UnresolvedText = $Unresolved | Sort-Object -Unique | Format-Table -AutoSize | Out-String
    }
    else {
        $UnresolvedText = "-->None detected"
    }

    $report += @"

UNRESOLVED
These commands may be called from nested commands or unknown modules.

$UnresolvedText
"@

    $danger = "Remove", "Stop", "Disconnect", "Suspend", "Block",
    "Disable", "Deny", "Unpublish", "Dismount", "Reset", "Resize",
    "Rename", "Redo", "Lock", "Hide", "Clear"

    $danger = $commands | Where-Object {$danger -contains $_.verb} | Sort-Object Name | Get-Unique

    if ($danger) {
        $DangerCommands = $($danger | Format-Table -AutoSize | Out-String).Trim()
    }
    else {
        $DangerCommands = "-->None detected"
    }


    $TypeTokens = $AstTokens | Where-Object {$_.TokenFlags -eq 'TypeName'}
    if ($TypeTokens ) {
        $foundTypes = $TypeTokens |
            Sort-Object @{expression = {$_.text.ToUpper()}} -unique |
            Select-Object -ExpandProperty Text | ForEach-Object { "[$_]"} | Out-String
    }
    else {
        $foundTypes = "-->None detected"
    }

    $report += @"

TYPENAMES
These are identified .NET type names that might be used as accelerators.

$foundTypes
"@

    $report += @"

WARNING
These are potentially dangerous commands.

$DangerCommands
"@


    $basename = (Get-Item $Path).basename
    $reportFile = Join-Path -Path $FilePath -ChildPath "ABOUT_$basename.help.txt"

    @"
TOPIC
about $basename profile

"@ |Out-File -FilePath $reportFile -Encoding ascii

    @"
SHORT DESCRIPTION
Script Profile report for: $Path

"@ | Out-File -FilePath $reportFile -Encoding ascii -Append

    @"
LONG DESCRIPTION
$report
"@  | Out-File -FilePath $reportFile -Encoding ascii -Append

    Notepad $reportFile

}

Function Get-ScriptComments {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = 'Enter the path of a PS1 file',
            ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PSPath', 'Name')]
        [ValidateScript( { Test-Path $_ })]
        [ValidatePattern('\.ps(1|m1)$')]
        [String]$Path
    )

    Begin {
        New-Variable $AstTokens -Force
        New-Variable astErr -Force
    }

    Process {
        $Path = Convert-Path -Path $Path

        $AST = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$AstTokens, [ref]$astErr)

        $AstTokens.where( { $_.kind -eq 'comment' }) |
        Select-Object -ExpandProperty Text
    }

    End {
    }

}

Function Get-SearchResult {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$Text = $psISE.CurrentFile.editor.selectedText,
        [ValidateSet("Bing", "Google", "Yahoo")]
        [String]$SearchEngine = "Google"
    )

    Switch ($SearchEngine) {
        "Bing" {
            $lang = (Get-Culture).parent.name
            $url = "http://www.bing.com/search?q=$text+language%3A$lang"
            Break
        }
        "Google" {
            $url = "http://www.google.com/search?q=$text"
        }
        "Yahoo" {
            $url = "http://search.yahoo.com/search?p=$text"
        }
    }


    Start-Process $url

}

Function New-CommentHelp {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = "What is the name of your function or command?" )]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter(Position = 1, Mandatory, HelpMessage = "Enter a brief synopsis" )]
        [ValidateNotNullOrEmpty()]
        [String]$Synopsis,

        [Parameter(Position = 2, Mandatory, HelpMessage = "Enter a description. You can expand and edit later" )]
        [ValidateNotNullOrEmpty()]
        [String]$Description
    )

    $comment = @"
"

    if ($psISE) {
        $psISE.CurrentFile.Editor.InsertText($help) | Out-Null
    }
    else {
        $help
    }

}

Function New-DSCResourceSnippet {

    [CmdletBinding(SupportsShouldProcess = $True, DefaultParameterSetName = 'Name')]
    Param(
        [Parameter(
            Position = 0,
            Mandatory,
            HelpMessage = 'Enter the name of a DSC resource',
            ParameterSetName = 'Name'
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
        [Parameter(
            Position = 0,
            Mandatory,
            HelpMessage = 'Enter the name of a DSC resource',
            ValueFromPipeline,
            ParameterSetName = 'Resource'
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]] $DSCResource,
        [ValidateNotNullOrEmpty()]
        [String]$Author = $env:username,
        [Switch]$PassThru
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            Try {
                $DSCResource = Get-DscResource -Name $Name -ErrorAction Stop
            }
            Catch {
                Throw
            }
        }

        foreach ($resource in $DSCResource) {

            [string[]]$entry = "`n$($resource.name) <ResourceID> {`n"

            $entry += "`t#from module $($resource.module.name)"
            $entry += foreach ($item in $resource.Properties) {
                if ($item.IsMandatory) {
                    $ResourceName = "`t*$($item.name)"
                }
                else {
                    $ResourceName = "`t$($item.name)"
                }

                if ($item.PropertyType -eq '[bool]') {
                    $possibleValues = "`$True | `$False"
                }
                elseif ($item.values) {
                    $possibleValues = "'$($item.Values -join "' | '")'"
                }
                else {
                    $possibleValues = $item.PropertyType
                }
                "$ResourceName = $($possibleValues)"

            }

            $entry += "`n}

            $title = "DSC $($resource.name) Resource"
            $description = "$($resource.name) resource from module $($resource.module) $($resource.CompanyName)"


            $paramHash = @{
                Title       = $Title
                Description = $description
                Text        = ($Entry | Out-String)
                Author      = $Author
                Force       = $True
                ErrorAction = 'Stop'
            }

            if ($PSCmdlet.ShouldProcess($Resource.name)) {

                Try {
                    Write-Debug 'Creating snippet file'
                    New-IseSnippet @paramHash

                    if ($PassThru) {
                        $SnipPath = Join-Path -Path "$env:Userprofile\documents\WindowsPowerShell\Snippets" -ChildPath "$title.snippets.ps1xml"
                        Get-Item -Path $SnipPath
                    }
                }
                Catch {
                    Throw
                }

            }
        }

    }

    End {
        Import-IseSnippet -Path "$env:Userprofile\documents\WindowsPowerShell\Snippets"
    }

}

Function New-FileHere {
    [CmdletBinding()]
    Param(
        [String]$Name = (New-InputBox -Prompt 'Enter a file name' -Title 'New File' -Default 'MyUntitled.ps1'),
        [Switch]$Open,
        [Switch]$PassThru
    )

    if ($name -match '\w+') {
        $NewPath = Join-Path -Path (Get-Location).Path -ChildPath $name
        if (Test-Path -Path $NewPath) {
            Write-Warning "A file with the name $name already exists. Please try again."
        }
        else {
            $head = @"

"@
            $head | Out-File -FilePath $NewPath -NoClobber

            Start-Sleep -Seconds 1

            if ($Open) {
                psedit $NewPath
            }
            if ($PassThru) {
                Get-Item $NewPath
            }

        }
    }
    else {
        Write-Host 'Aborting' -ForegroundColor Yellow
    }
}

Function New-Function {

    $name = Read-Host "What do you want to call the new function?"

    $functionText = @"

Function $name {

[CmdletBinding()]

Param(
[Parameter(Position=0,Mandatory=`$False,ValueFromPipeline=`$True)]
[string[]]`$FOO

)

Begin {

}

Process {
    Foreach (`$item in `$FOO) {

    }

}

End {
}

}

"@

    $psISE.CurrentFile.Editor.InsertText($FunctionText)

}

Function New-InputBox {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory, HelpMessage = 'Enter a message prompt')]
        [ValidateNotNullOrEmpty()]
        [String]$Prompt,
        [Parameter(Position = 1)]
        [String]$Title = 'Input',
        [Parameter(Position = 2)]
        [String]$Default

    )

    Try {
        Add-Type -AssemblyName 'Microsoft.VisualBasic' -ErrorAction Stop
        [Microsoft.VisualBasic.interaction]::InputBox($Prompt, $Title, $Default)
    }
    Catch {
        Write-Warning 'There was a problem creating the InputBox'
        Write-Warning $_.Exception.Message
    }

}

Function New-PSCommand {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory, HelpMessage = 'Enter the name of your new command')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
        [ValidateScript( {
                ($_ -is [hashtable]) -OR ($_ -is [System.Collections.Specialized.OrderedDictionary])
            })]

        [Alias('Parameters')]
        [object]$NewParameters,
        [Switch]$ShouldProcess,
        [String]$Synopsis,
        [String]$Description,
        [String]$BeginCode,
        [String]$ProcessCode,
        [String]$EndCode,
        [Switch]$UseISE
    )

    $MyParams = ''
    $HelpParams = ''


    foreach ($k in $NewParameters.keys) {
        $ParamSettings = $NewParameters.item($k)

        if ($ParamSettings.count -gt 1) {
            $ParamType = $ParamSettings[0]
            if ($ParamSettings[1] -is [object]) {
                $Mandatory = "Mandatory=`${0}," -f $ParamSettings[1]
            }
            if ($ParamSettings[2] -is [object]) {
                $PipelineValue = "ValueFromPipeline=`${0}," -f $ParamSettings[2]
            }
            if ($ParamSettings[3] -is [object]) {
                $PipelineName = "ValueFromPipelineByPropertyName=`${0}" -f $ParamSettings[3]
            }
            if ($ParamSettings[4] -is [object]) {
                $Position = 'Position={0},' -f $ParamSettings[4]
            }
        }
        else {
            $ParamType = $ParamSettings
        }

        $item = "[Parameter({0}{1}{2}{3})]`n" -f $Position, $Mandatory, $PipelineValue, $PipelineName
        $item += "[{0}]`${1}" -f $ParamType, $k
        $MyParams += "$item, `n"
        $HelpParams += ".PARAMETER {0} `n`n" -f $k
        Clear-Variable 'Position', 'Mandatory', 'PipelineValue', 'PipelineName', 'ParamSettings' -ErrorAction SilentlyContinue

    }

    $MyParams = $MyParams.Remove($MyParams.lastIndexOf(','))

    $text = @"

Function $name {

[CmdletBinding(SupportsShouldProcess=`$$ShouldProcess)]

Param (
$MyParams
)

Begin {
    $BeginCode
}

Process {
    $ProcessCode
}

End {
    $EndCode
}

}

"@

    if ($UseISE -and $psISE) {
        $NewFile = $psISE.CurrentPowerShellTab.Files.Add()
        $NewFile.Editor.InsertText($Text)
    }
    else {
        $Text
    }


}

Function Open-SelectedISE {
    [CmdletBinding()]
    Param([String]$Text = $psISE.CurrentFile.Editor.SelectedText)

    $file = $Text.Trim()

    if (Test-Path -Path $file ) {
        psedit $file
    }
    else {
        Write-Warning "Can't find $file"
    }

}

Function Out-ISETab {
    [CmdletBinding()]
    [alias('tab')]

    Param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,
        [Switch]$UseCurrentFile
    )

    Begin {


        if ($UseCurrentFile) {
            $tab = $psISE.CurrentFile
        }
        else {
            $tab = $psISE.CurrentPowerShellTab.Files.Add()
        }

        $data = @()
    }
    Process {
        $data += $InputObject
    }

    End {
        $tab.Editor.InsertText(($data | Out-String))
    }

}

Function Send-ToPrinter {
  [CmdletBinding()]
  Param([String]$path = $psISE.CurrentFile.FullPath)

  Start-Process -FilePath Notepad.exe -ArgumentList '/p', $path -WindowStyle Hidden

}

Function Reset-ISEFile {
    [cmdletbinding()]
    Param()
    $path = $psISE.CurrentFile.FullPath
    $i = $psISE.CurrentPowerShellTab.files.IndexOf($psISE.CurrentFile)
    [void]$psISE.CurrentPowerShellTab.Files.Remove($psISE.CurrentFile)
    [void]$psISE.CurrentPowerShellTab.Files.Add($path)
    [void]$psISE.CurrentPowerShellTab.files.Move(($psISE.CurrentPowerShellTab.files.count - 1), $i)

}

Function Write-Signature {
    [cmdletbinding(SupportsShouldProcess)]
    Param()

    Set-StrictMode -Version Latest

    $cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Verify() }
    If ($cert.Count -eq '0') {
        Write-Warning 'No code signing certificate found.'
        Exit
    }
    ElseIf ($cert.Count -gt '1') {
        $cert = ($cert | Out-GridView -Title 'Select the desired code signing certificate' -OutputMode Single)
    }

    if (!$psISE.CurrentFile.IsSaved) {
        $psISE.CurrentFile.Save()
    }

    if ($psISE.CurrentFile.Encoding.EncodingName -match 'Big-Endian') {
        $psISE.CurrentFile.Save([Text.Encoding]::Unicode) | Out-Null
    }

    $filepath = $psISE.CurrentFile.FullPath

    Try {
        Set-AuthenticodeSignature -FilePath $filepath -Certificate $cert -ErrorAction Stop
        $psISE.CurrentPowerShellTab.Files.Remove(($psISE.CurrentFile)) | Out-Null

        $psISE.CurrentPowerShellTab.Files.Add(($filepath)) | Out-Null
    }
    Catch {
        Write-Warning ('Script signing failed. {0}' -f $_.Exception.message)
    }
}

Function Get-CommandMetadata {
    [CmdletBinding()]
    [alias('gcmd')]
    Param(
        [Parameter(
            Position = 0,
            Mandatory,
            HelpMessage = 'Enter the name of a PowerShell command'
        )]
        [ValidateNotNullOrEmpty()]
        [String]$Command,
        [String]$NewName,
        [Switch]$NoHelp
    )

    Try {
        $gcm = Get-Command -Name $command -ErrorAction Stop
        if ($gcm.CommandType -eq 'Alias') {
            $CmdName = $gcm.ResolvedCommandName
        }
        else {
            $CmdName = $gcm.Name
        }
        $cmd = New-Object System.Management.Automation.CommandMetaData ($gcm)
    }
    Catch {
        Write-Warning "Failed to create command metadata for $command"
        Write-Warning $_.Exception.Message
    }

    if ($cmd) {

        if ($NewName) {
            $Name = $NewName
        }
        else {
            $Name = $cmd.Name
        }

        if ($noHelp) {
            $cmd.HelpUri = $Null

            $myHelp = @"

.Synopsis
PUT SYNTAX HERE
.Description
PUT DESCRIPTION HERE
.Notes
Created:`t$(Get-Date -Format d)

.Example
PS C:\> $Name

.Link
$CmdName

"@
            $metadata = [System.Management.Automation.ProxyCommand]::Create($cmd, $myHelp)

        }
        else {
            $metadata = [System.Management.Automation.ProxyCommand]::Create($cmd)
        }

        [regex]$rx = '[\s+]\$\{\w+\}[,|)]'
        $metadata = $metadata.split("`n") | ForEach-Object {
            If ($rx.IsMatch($_)) {
                $rx.Match($_).Value.Replace('{', '').Replace('}', '')
            }
            else {
                $_
            }
        }

        $text = @"

Function $Name {

$metadata

}
"@
        if ($host.Name -match 'PowerShell ISE') {
            $tab = $psISE.CurrentPowerShellTab.Files.Add()

            $tab.editor.InsertText($Text)

            $tab.Editor.SetCaretPosition(1, 1)
        }
        else {
            $Text
        }
    }

}
