Function New-PSCommand {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory, HelpMessage = 'Enter the name of your new command')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
        [ValidateScript( {
                #test if using a hashtable or an [ordered] hash table in v3 or later
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

    Write-Verbose "Starting $($MyInvocation.MyCommand)"
    #add parameters
    $MyParams = ''
    $HelpParams = ''

    Write-Verbose 'Processing parameter names'

    foreach ($k in $NewParameters.keys) {
        Write-Verbose "  $k"
        $ParamSettings = $NewParameters.item($k)

        #process any remaining elements from the hashtable value
        #@{ParamName="type[]",Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,Position}

        if ($ParamSettings.count -gt 1) {
            $ParamType = $ParamSettings[0]
            if ($ParamSettings[1] -is [object]) {
                $Mandatory = "Mandatory=`${0}," -f $ParamSettings[1]
                Write-Verbose $Mandatory
            }
            if ($ParamSettings[2] -is [object]) {
                $PipelineValue = "ValueFromPipeline=`${0}," -f $ParamSettings[2]
                Write-Verbose $PipelineValue
            }
            if ($ParamSettings[3] -is [object]) {
                $PipelineName = "ValueFromPipelineByPropertyName=`${0}" -f $ParamSettings[3]
                Write-Verbose $PipelineName
            }
            if ($ParamSettings[4] -is [object]) {
                $Position = 'Position={0},' -f $ParamSettings[4]
                Write-Verbose $Position
            }
        }
        else {
            #the only hash key is the parameter type
            $ParamType = $ParamSettings
        }

        $item = "[Parameter({0}{1}{2}{3})]`n" -f $Position, $Mandatory, $PipelineValue, $PipelineName
        $item += "[{0}]`${1}" -f $ParamType, $k
        Write-Verbose "Adding $item to MyParams"
        $MyParams += "$item, `n"
        $HelpParams += ".PARAMETER {0} `n`n" -f $k
        #clear variables but ignore errors for those that don't exist
        Clear-Variable 'Position', 'Mandatory', 'PipelineValue', 'PipelineName', 'ParamSettings' -ErrorAction SilentlyContinue

    } #foreach hash key

    #get trailing comma and remove it
    $MyParams = $MyParams.Remove($MyParams.lastIndexOf(','))

    Write-Verbose 'Building text'
    $text = @"
#requires -version 5.1

Function $name {
<#
.SYNOPSIS
$Synopsis

.DESCRIPTION
$Description

$HelpParams
.EXAMPLE
PS C:\> $Name

.NOTES
Version: 0.1
Author : $env:username

.INPUTS

.OUTPUTS

.LINK
#>

[CmdletBinding(SupportsShouldProcess=`$$ShouldProcess)]

Param (
$MyParams
)

Begin {
    Write-Verbose "Starting `$(`$MyInvocation.MyCommand)"
    $BeginCode
} #begin

Process {
    $ProcessCode
} #process

End {
    $EndCode
    Write-Verbose "Ending `$(`$MyInvocation.MyCommand)"
} #end

} #end $name function

"@

    if ($UseISE -and $psISE) {
        $NewFile = $psISE.CurrentPowerShellTab.Files.Add()
        $NewFile.Editor.InsertText($Text)
    }
    else {
        $Text
    }

    Write-Verbose "Ending $($MyInvocation.MyCommand)"

} #end New-PSCommand function
