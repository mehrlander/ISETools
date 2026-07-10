#requires -Version 5.1
param(
    [string]$Biennium = '2025-26',
    [string]$LegRoot = (Join-Path $env:USERPROFILE 'OneDrive\\Documents\\WindowsPowerShell\\Leg'),
    [string]$AnnotationFile,
    [string]$LegModulePath
)

$ErrorActionPreference = 'Stop'

if ($null -eq $AnnotationFile -or '' -eq $AnnotationFile) {
    $AnnotationFile = Join-Path $LegRoot 'BillAnnotations.json'
}

if ($null -ne $LegModulePath -and '' -ne $LegModulePath -and (Test-Path -LiteralPath $LegModulePath)) {
    Import-Module -Name $LegModulePath -Force
}
else {
    Import-Module -Name Leg -ErrorAction Stop
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

function ConvertTo-Hashtable {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return @{}
    }

    $hash = @{}
    $InputObject.PSObject.Properties | ForEach-Object {
        $hash[$_.Name] = $_.Value
    }
    return $hash
}

function Load-Annotations {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{}
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ($null -eq $raw -or '' -eq $raw.Trim()) {
        return @{}
    }

    $parsed = $raw | ConvertFrom-Json
    if ($null -eq $parsed) {
        return @{}
    }

    return ConvertTo-Hashtable -InputObject $parsed
}

function Save-Annotations {
    param(
        [hashtable]$Annotations,
        [string]$Path
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        [void](New-Item -ItemType Directory -Path $dir)
    }

    $Annotations | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-AnnotationKey {
    param(
        $Record
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetFileNameWithoutExtension($Record.Path))
    return Join-Path (Join-Path $Record.Biennium $Record.Folder) $baseName
}

function Format-StatusLabel {
    param(
        $Annotation
    )

    if ($null -eq $Annotation) {
        return 'Unreviewed'
    }

    if ($null -ne $Annotation.reviewed -and '' -ne $Annotation.reviewed) {
        return "Reviewed $($Annotation.reviewed)"
    }

    if ($Annotation.affectsDRS) {
        return 'Agency Impact'
    }

    if ($null -ne $Annotation.notes -and '' -ne $Annotation.notes.Trim()) {
        return 'Annotated'
    }

    return 'Unreviewed'
}

function Set-AnnotationFields {
    param(
        $Record,
        [hashtable]$Annotations
    )

    $key = Get-AnnotationKey -Record $Record
    if ($Annotations.ContainsKey($key)) {
        $Record.Annotation = $Annotations[$key]
    }
    else {
        $Record.Annotation = $null
    }

    $Record.StatusLabel = Format-StatusLabel -Annotation $Record.Annotation
    if ($null -ne $Record.Annotation -and $Record.Annotation.PSObject.Properties.Name -contains 'fiscalNote') {
        if ($null -ne $Record.Annotation.fiscalNote -and '' -ne $Record.Annotation.fiscalNote) {
            $Record.FiscalNoteLabel = $Record.Annotation.fiscalNote
        }
        else {
            $Record.FiscalNoteLabel = 'None'
        }
    }
    else {
        $Record.FiscalNoteLabel = 'None'
    }

    if ($null -ne $Record.Annotation -and $Record.Annotation.PSObject.Properties.Name -contains 'notes') {
        if ($null -ne $Record.Annotation.notes -and '' -ne $Record.Annotation.notes.Trim()) {
            $previewLength = [Math]::Min(80, $Record.Annotation.notes.Length)
            $Record.NotesPreview = $Record.Annotation.notes.Substring(0, $previewLength)
        }
        else {
            $Record.NotesPreview = ''
        }
    }
    else {
        $Record.NotesPreview = ''
    }
}

function Get-BillRecords {
    param(
        [string]$Biennium,
        [string]$LegRoot,
        [hashtable]$Annotations
    )

    $bienniumFolder = Join-Path (Join-Path $LegRoot 'Bills') $Biennium
    if (-not (Test-Path -LiteralPath $bienniumFolder)) {
        return @()
    }

    $files = Get-ChildItem -Path $bienniumFolder -Recurse -Filter '*.xml.gz' -File
    $records = @()

    foreach ($file in $files) {
        $meta = Get-BillXml -Path $file.FullName
        $folder = Split-Path -Leaf $file.DirectoryName
        $record = [PSCustomObject]@{
            BillNum       = $meta.BillNum
            Title         = $meta.Title
            Chamber       = $meta.Chamber
            BillType      = ($folder -replace '_', ' ')
            Folder        = $folder
            Path          = $file.FullName
            Biennium      = $Biennium
            ShortId       = $meta.ShortId
            LastModified  = $file.LastWriteTime
            StatusLabel   = ''
            FiscalNoteLabel = ''
            NotesPreview  = ''
            Annotation    = $null
        }

        Set-AnnotationFields -Record $record -Annotations $Annotations
        $records += $record
    }

    return $records
}

function Read-RcwLinks {
    param(
        $Record
    )

    $rootName = [System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetFileNameWithoutExtension($Record.Path))
    $htmPath = Join-Path (Split-Path -Parent $Record.Path) "$rootName.htm.gz"
    if (-not (Test-Path -LiteralPath $htmPath)) {
        return @()
    }

    $htm = Get-BillHtm -Path $htmPath
    if ($null -eq $htm) {
        return @()
    }

    if ($htm.PSObject.Properties.Name -contains 'RcwLinks' -and $null -ne $htm.RcwLinks) {
        return $htm.RcwLinks
    }

    return @()
}

function Update-BillDetail {
    param(
        $Record,
        $Controls
    )

    if ($null -eq $Record) {
        $Controls.SelectedTitle.Text = 'Select a bill to view details.'
        $Controls.SelectedMeta.Text = ''
        $Controls.RcwLinksText.Text = ''
        $Controls.AffectsDrs.IsChecked = $false
        $Controls.FiscalNoteBox.SelectedIndex = 0
        $Controls.NotesBox.Text = ''
        $Controls.TagsBox.Text = ''
        $Controls.ReviewedLabel.Text = 'Not reviewed'
        return
    }

    $Controls.SelectedTitle.Text = "$($Record.BillNum) - $($Record.Title)"
    $Controls.SelectedMeta.Text = "Chamber: $($Record.Chamber) | Type: $($Record.BillType) | Last modified: $($Record.LastModified)"

    $links = Read-RcwLinks -Record $Record
    if ($null -ne $links -and $links.Count -gt 0) {
        $Controls.RcwLinksText.Text = [string]::Join(', ', $links)
    }
    else {
        $Controls.RcwLinksText.Text = 'No RCW links found.'
    }

    if ($null -ne $Record.Annotation) {
        $Controls.AffectsDrs.IsChecked = [bool]$Record.Annotation.affectsDRS

        $fiscalNote = $Record.Annotation.fiscalNote
        $index = $Controls.FiscalNoteBox.Items.IndexOf($fiscalNote)
        if ($index -lt 0) {
            $Controls.FiscalNoteBox.SelectedIndex = 0
        }
        else {
            $Controls.FiscalNoteBox.SelectedIndex = $index
        }

        if ($null -ne $Record.Annotation.notes) {
            $Controls.NotesBox.Text = $Record.Annotation.notes
        }
        else {
            $Controls.NotesBox.Text = ''
        }

        if ($null -ne $Record.Annotation.tags) {
            $Controls.TagsBox.Text = ($Record.Annotation.tags -join ', ')
        }
        else {
            $Controls.TagsBox.Text = ''
        }

        if ($null -ne $Record.Annotation.reviewed -and '' -ne $Record.Annotation.reviewed) {
            $Controls.ReviewedLabel.Text = "Reviewed on $($Record.Annotation.reviewed)"
        }
        else {
            $Controls.ReviewedLabel.Text = 'Not reviewed'
        }
    }
    else {
        $Controls.AffectsDrs.IsChecked = $false
        $Controls.FiscalNoteBox.SelectedIndex = 0
        $Controls.NotesBox.Text = ''
        $Controls.TagsBox.Text = ''
        $Controls.ReviewedLabel.Text = 'Not reviewed'
    }
}

function Persist-Annotation {
    param(
        $Record,
        [hashtable]$Annotations,
        $Controls,
        [string]$AnnotationFile
    )

    if ($null -eq $Record) {
        return
    }

    $tags = @()
    if ($null -ne $Controls.TagsBox.Text -and '' -ne $Controls.TagsBox.Text.Trim()) {
        $Controls.TagsBox.Text.Split(',') | ForEach-Object {
            $tag = $_.Trim()
            if ('' -ne $tag) {
                $tags += $tag
            }
        }
    }

    $annotation = [PSCustomObject]@{
        affectsDRS = [bool]$Controls.AffectsDrs.IsChecked
        fiscalNote = [string]$Controls.FiscalNoteBox.SelectedItem
        notes      = [string]$Controls.NotesBox.Text
        tags       = $tags
        reviewed   = $null
    }

    if ($Controls.ReviewedLabel.Text -like 'Reviewed on *') {
        $annotation.reviewed = $Controls.ReviewedLabel.Text.Replace('Reviewed on ', '')
    }

    $key = Get-AnnotationKey -Record $Record
    $Annotations[$key] = $annotation
    Save-Annotations -Annotations $Annotations -Path $AnnotationFile
    Set-AnnotationFields -Record $Record -Annotations $Annotations
}

function Mark-Reviewed {
    param(
        $Record,
        $Controls,
        [hashtable]$Annotations,
        [string]$AnnotationFile
    )

    if ($null -eq $Record) {
        return
    }

    $today = Get-Date -Format 'yyyy-MM-dd'
    $Controls.ReviewedLabel.Text = "Reviewed on $today"
    Persist-Annotation -Record $Record -Annotations $Annotations -Controls $Controls -AnnotationFile $AnnotationFile
}

function Clear-Reviewed {
    param(
        $Record,
        $Controls,
        [hashtable]$Annotations,
        [string]$AnnotationFile
    )

    if ($null -eq $Record) {
        return
    }

    $Controls.ReviewedLabel.Text = 'Not reviewed'
    Persist-Annotation -Record $Record -Annotations $Annotations -Controls $Controls -AnnotationFile $AnnotationFile
}

function Apply-Filters {
    param(
        $AllBills,
        $Controls
    )

    $search = $Controls.SearchBox.Text
    $billTypeFilter = $Controls.BillTypeFilter.SelectedItem
    $chamberFilter = $Controls.ChamberFilter.SelectedItem
    $statusFilter = $Controls.StatusFilter.SelectedItem

    $filtered = $AllBills | Where-Object {
        $matches = $true

        if ($null -ne $billTypeFilter -and 'All bill types' -ne $billTypeFilter) {
            $matches = $matches -and ($_.BillType -eq $billTypeFilter)
        }

        if ($null -ne $chamberFilter -and 'All chambers' -ne $chamberFilter) {
            $matches = $matches -and ($_.Chamber -eq $chamberFilter)
        }

        if ($null -ne $statusFilter -and 'All statuses' -ne $statusFilter) {
            if ('Reviewed only' -eq $statusFilter) {
                $matches = $matches -and ($_.StatusLabel -like 'Reviewed*')
            }
            elseif ('Annotated only' -eq $statusFilter) {
                $matches = $matches -and ($_.StatusLabel -eq 'Annotated' -or $_.StatusLabel -eq 'Agency Impact')
            }
            elseif ('Unreviewed only' -eq $statusFilter) {
                $matches = $matches -and ($_.StatusLabel -eq 'Unreviewed')
            }
        }

        if ($null -ne $search -and '' -ne $search.Trim()) {
            $matches = $matches -and ($_.BillNum -like "*$search*" -or $_.Title -like "*$search*")
        }

        return $matches
    }

    $Controls.BillGrid.ItemsSource = $filtered
    $Controls.BillGrid.Items.Refresh()
    $Controls.StatusText.Text = "Showing $($filtered.Count) of $($AllBills.Count) bills"
}

function Refresh-Bills {
    param(
        [string]$Biennium,
        [string]$LegRoot,
        [hashtable]$Annotations,
        $Controls
    )

    $Controls.StatusText.Text = 'Loading bills...'
    $Controls.StatusText.ToolTip = ''
    $records = Get-BillRecords -Biennium $Biennium -LegRoot $LegRoot -Annotations $Annotations
    $script:AllBills = $records
    Apply-Filters -AllBills $records -Controls $Controls
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WA Bill Dashboard" Height="720" Width="1100">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="260" />
        </Grid.RowDefinitions>

        <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0 0 0 8">
            <Button Name="RefreshButton" Content="Refresh" Width="90" Margin="0 0 8 0" />
            <Button Name="ImportButton" Content="Import New" Width="100" Margin="0 0 16 0" />

            <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0 0 4 0" />
            <TextBox Name="SearchBox" Width="180" Margin="0 0 16 0" />

            <TextBlock Text="Bill Type:" VerticalAlignment="Center" Margin="0 0 4 0" />
            <ComboBox Name="BillTypeFilter" Width="170" Margin="0 0 12 0" />

            <TextBlock Text="Chamber:" VerticalAlignment="Center" Margin="0 0 4 0" />
            <ComboBox Name="ChamberFilter" Width="120" Margin="0 0 12 0" />

            <TextBlock Text="Status:" VerticalAlignment="Center" Margin="0 0 4 0" />
            <ComboBox Name="StatusFilter" Width="150" />
        </StackPanel>

        <DataGrid Name="BillGrid" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Single" HeadersVisibility="Column" Margin="0 0 0 8">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Bill #" Binding="{Binding BillNum}" Width="90" />
                <DataGridTextColumn Header="Title" Binding="{Binding Title}" Width="300" />
                <DataGridTextColumn Header="Chamber" Binding="{Binding Chamber}" Width="90" />
                <DataGridTextColumn Header="Type" Binding="{Binding BillType}" Width="160" />
                <DataGridTextColumn Header="Status" Binding="{Binding StatusLabel}" Width="140" />
                <DataGridTextColumn Header="Fiscal" Binding="{Binding FiscalNoteLabel}" Width="90" />
                <DataGridTextColumn Header="Notes" Binding="{Binding NotesPreview}" Width="200" />
                <DataGridTextColumn Header="Modified" Binding="{Binding LastModified}" Width="150" />
            </DataGrid.Columns>
        </DataGrid>

        <Grid Grid.Row="2">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto" />
                <RowDefinition Height="*" />
            </Grid.RowDefinitions>

            <TextBlock Name="StatusText" Grid.Row="0" Margin="0 0 0 6" />

            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="2*" />
                    <ColumnDefinition Width="3*" />
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Margin="0 0 12 0">
                    <TextBlock Name="SelectedTitle" FontSize="14" FontWeight="Bold" TextWrapping="Wrap" />
                    <TextBlock Name="SelectedMeta" Margin="0 4 0 10" TextWrapping="Wrap" />
                    <TextBlock Text="RCW Links:" FontWeight="SemiBold" />
                    <TextBlock Name="RcwLinksText" TextWrapping="Wrap" Margin="0 2 0 12" />
                    <Button Name="PreviewButton" Content="Open File" Width="100" />
                </StackPanel>

                <StackPanel Grid.Column="1">
                    <StackPanel Orientation="Horizontal" Margin="0 0 0 6">
                        <CheckBox Name="AffectsDrs" Content="Affects DRS" Width="120" />
                        <TextBlock Text="Fiscal:" VerticalAlignment="Center" Margin="12 0 4 0" />
                        <ComboBox Name="FiscalNoteBox" Width="150" />
                        <Button Name="ReviewedButton" Content="Mark Reviewed" Width="120" Margin="12 0 0 0" />
                        <Button Name="ClearReviewedButton" Content="Clear" Width="60" Margin="6 0 0 0" />
                    </StackPanel>

                    <TextBlock Name="ReviewedLabel" Margin="0 0 0 8" />

                    <TextBlock Text="Tags (comma-separated):" />
                    <TextBox Name="TagsBox" Margin="0 0 0 8" />

                    <TextBlock Text="Notes:" />
                    <TextBox Name="NotesBox" AcceptsReturn="True" Height="120" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" />

                    <StackPanel Orientation="Horizontal" Margin="0 8 0 0">
                        <Button Name="SaveButton" Content="Save Annotation" Width="140" />
                    </StackPanel>
                </StackPanel>
            </Grid>
        </Grid>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$WPF = @{}
$xaml.SelectNodes("//*[@*[local-name()='Name']]") | ForEach-Object {
    $name = $_.Attributes['Name'].Value
    if ($null -eq $name -or '' -eq $name) {
        $name = $_.Attributes['x:Name'].Value
    }
    $WPF[$name] = $window.FindName($name)
}

$annotations = Load-Annotations -Path $AnnotationFile

$billTypes = Get-BillType -Biennium $Biennium
if ($null -eq $billTypes) {
    $billTypes = @()
}

$WPF.BillTypeFilter.Items.Add('All bill types')
foreach ($type in $billTypes) {
    $WPF.BillTypeFilter.Items.Add($type)
}
$WPF.BillTypeFilter.SelectedIndex = 0

$WPF.ChamberFilter.Items.Add('All chambers')
$WPF.ChamberFilter.Items.Add('House')
$WPF.ChamberFilter.Items.Add('Senate')
$WPF.ChamberFilter.SelectedIndex = 0

$WPF.StatusFilter.Items.Add('All statuses')
$WPF.StatusFilter.Items.Add('Reviewed only')
$WPF.StatusFilter.Items.Add('Annotated only')
$WPF.StatusFilter.Items.Add('Unreviewed only')
$WPF.StatusFilter.SelectedIndex = 0

$WPF.FiscalNoteBox.Items.Add('None')
$WPF.FiscalNoteBox.Items.Add('Requested')
$WPF.FiscalNoteBox.Items.Add('Received')
$WPF.FiscalNoteBox.Items.Add('Reviewed')
$WPF.FiscalNoteBox.SelectedIndex = 0

$script:AllBills = @()
$script:SelectedRecord = $null

Refresh-Bills -Biennium $Biennium -LegRoot $LegRoot -Annotations $annotations -Controls $WPF
Update-BillDetail -Record $null -Controls $WPF

$WPF.SearchBox.Add_TextChanged({
    Apply-Filters -AllBills $script:AllBills -Controls $WPF
})

$WPF.BillTypeFilter.Add_SelectionChanged({
    Apply-Filters -AllBills $script:AllBills -Controls $WPF
})

$WPF.ChamberFilter.Add_SelectionChanged({
    Apply-Filters -AllBills $script:AllBills -Controls $WPF
})

$WPF.StatusFilter.Add_SelectionChanged({
    Apply-Filters -AllBills $script:AllBills -Controls $WPF
})

$WPF.RefreshButton.Add_Click({
    Refresh-Bills -Biennium $Biennium -LegRoot $LegRoot -Annotations $annotations -Controls $WPF
})

$WPF.ImportButton.Add_Click({
    $chosenType = $WPF.BillTypeFilter.SelectedItem
    if ($null -eq $chosenType -or 'All bill types' -eq $chosenType) {
        if ($billTypes.Count -gt 0) {
            $chosenType = $billTypes[0]
        }
    }

    if ($null -eq $chosenType) {
        $WPF.StatusText.Text = 'Select a bill type to import.'
        return
    }

    $WPF.StatusText.Text = "Importing $chosenType..."
    Import-Bill -BillType $chosenType -Format xml
    Import-Bill -BillType $chosenType -Format htm
    Refresh-Bills -Biennium $Biennium -LegRoot $LegRoot -Annotations $annotations -Controls $WPF
    $WPF.StatusText.Text = "Import complete for $chosenType"
})

$WPF.BillGrid.Add_SelectionChanged({
    $selected = $WPF.BillGrid.SelectedItem
    $script:SelectedRecord = $selected
    Update-BillDetail -Record $selected -Controls $WPF
})

$WPF.SaveButton.Add_Click({
    Persist-Annotation -Record $script:SelectedRecord -Annotations $annotations -Controls $WPF -AnnotationFile $AnnotationFile
    Apply-Filters -AllBills $script:AllBills -Controls $WPF
})

$WPF.ReviewedButton.Add_Click({
    Mark-Reviewed -Record $script:SelectedRecord -Controls $WPF -Annotations $annotations -AnnotationFile $AnnotationFile
    Apply-Filters -AllBills $script:AllBills -Controls $WPF
})

$WPF.ClearReviewedButton.Add_Click({
    Clear-Reviewed -Record $script:SelectedRecord -Controls $WPF -Annotations $annotations -AnnotationFile $AnnotationFile
    Apply-Filters -AllBills $script:AllBills -Controls $WPF
})

$WPF.PreviewButton.Add_Click({
    if ($null -eq $script:SelectedRecord) {
        return
    }

    $folder = Split-Path -Parent $script:SelectedRecord.Path
    $rootName = [System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetFileNameWithoutExtension($script:SelectedRecord.Path))
    $target = Join-Path $folder "$rootName.xml.gz"
    if (-not (Test-Path -LiteralPath $target)) {
        $target = Join-Path $folder "$rootName.htm.gz"
    }

    if (Test-Path -LiteralPath $target) {
        Invoke-Item -LiteralPath $target
    }
})

[void]$window.ShowDialog()
