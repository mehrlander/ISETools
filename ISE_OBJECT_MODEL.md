# ISE Object Model Reference: Extracted from ISEScriptingGeek

This document catalogs the PowerShell ISE object model as revealed through actual usage in the ISEScriptingGeek module. It shows methods, properties, and interaction patterns for working with the ISE programmatically.

---

## Object Hierarchy

```
$psISE (ISE root object)
├── CurrentFile
│   ├── Editor
│   │   ├── SelectedText
│   │   ├── Text (full file content)
│   │   ├── CaretLine
│   │   ├── CaretColumn
│   │   └── [Methods]
│   └── FullPath
├── CurrentPowerShellTab
│   ├── Files (collection)
│   │   ├── SelectedFile
│   │   ├── Add()
│   │   └── [Indexing by path]
│   └── [Invoke operations]
├── PowerShellTabs (collection)
└── [Menu/UI elements]
```

---

## $psISE.CurrentFile — Current Editor Context

### Properties

| Property | Type | Purpose | Example |
|----------|------|---------|---------|
| `FullPath` | string | Complete file path on disk | `$psISE.CurrentFile.FullPath` → `"C:\scripts\myfunc.ps1"` |
| `DisplayName` | string | File name shown in tab | Same as filename in editor tab |
| `IsUntitled` | bool | Whether file has been saved | True for unsaved new files |

**Files used:** CloseAllFiles.ps1, Out-ISETab.ps1, Reload-ISEFile.ps1

### $psISE.CurrentFile.Editor — Text Editing Interface

#### Properties

| Property | Type | Purpose | Example |
|----------|------|---------|---------|
| `SelectedText` | string | Currently selected text | Read and write |
| `Text` | string | **Entire file content** | Full script as single string |
| `CaretLine` | int | Current cursor line number | `$line = $psISE.CurrentFile.Editor.CaretLine` |
| `CaretColumn` | int | Current cursor column position | `$col = $psISE.CurrentFile.Editor.CaretColumn` |

**Note:** Line numbers are 1-indexed.

#### Methods

| Method | Signature | Purpose | Example |
|--------|-----------|---------|---------|
| `InsertText(text)` | `void` | Insert text at cursor or replace selection | `$psISE.CurrentFile.Editor.InsertText("new code")` |
| `SetCaretPosition(line, column)` | `void` | Move cursor to specific location | `$psISE.CurrentFile.Editor.SetCaretPosition(42, 1)` |
| `Select(startLine, startColumn, endLine, endColumn)` | `void` | Select text range | `$psISE.CurrentFile.Editor.Select(10, 1, 15, 10)` |

**Key insight:** `InsertText()` replaces selected text if text is selected; otherwise inserts at cursor.

**Files demonstrating this:**
- ConvertFrom-Alias.ps1: `Select()` + `InsertText()` pattern for replacing aliases
- Find-InFile.ps1: `SetCaretPosition()` for navigation
- Bookmarks.ps1: `SetCaretPosition()` to jump to bookmarks
- Convert-CommandToHash.ps1: `InsertText()` to replace parameter syntax

---

## $psISE.CurrentPowerShellTab — Tab Management

### Properties

| Property | Type | Purpose | Example |
|----------|------|---------|---------|
| `Files` | collection | Collection of open files in this tab | `$psISE.CurrentPowerShellTab.Files` |
| `Files.SelectedFile` | file object | Currently active file | `$psISE.CurrentPowerShellTab.Files.SelectedFile` |

### $psISE.CurrentPowerShellTab.Files — File Collection

#### Methods

| Method | Signature | Purpose | Example |
|--------|-----------|---------|---------|
| `Add()` | returns file object | Create new unsaved file in tab | `$newFile = $psISE.CurrentPowerShellTab.Files.Add()` |

#### Properties

| Property | Type | Purpose | Notes |
|----------|------|---------|-------|
| `SelectedFile` | file object | Get/set active file | `$psISE.CurrentPowerShellTab.Files.SelectedFile = $f` |
| `.Count` | int | Number of open files | `$psISE.CurrentPowerShellTab.Files.Count` |
| `[index]` | file object | Access by index (0-based) | `$file = $psISE.CurrentPowerShellTab.Files[0]` |

#### Iteration

```powershell
# Iterate all open files
foreach ($file in $psISE.CurrentPowerShellTab.Files) {
    Write-Host $file.FullPath
}

# Find file by path (exact match)
$targetFile = $psISE.CurrentPowerShellTab.Files | Where-Object { $_.FullPath -eq "C:\path\file.ps1" }

# Select by index
$lastFile = $psISE.CurrentPowerShellTab.Files[-1]
```

**Files demonstrating this:**
- CloseAllFiles.ps1: Iterates collection, closes each
- Find-InFile.ps1: Selects files, uses `SelectedFile` assignment
- Out-ISETab.ps1: Uses `Add()` to create new file

---

## File Closing Pattern

**Challenge:** ISE doesn't expose a direct "Close" method on file objects.

**Solution (from CloseAllFiles.ps1):**
```powershell
# Workaround: Remove file from collection
$psISE.CurrentPowerShellTab.Files.Remove($file)
```

This removes the file from the open files collection. If unsaved, ISE prompts to save.

**Note:** The Remove() method is called on the collection, not the file object.

---

## Text Selection and Replacement Pattern

**Demonstrated in:** ConvertFrom-Alias.ps1, Convert-CommandToHash.ps1

### Pattern: Find → Select → Replace

```powershell
# Step 1: Parse/analyze text (e.g., tokenize to find aliases)
$tokens = [System.Management.Automation.PSParser]::Tokenize($text, [ref]$out)

# Step 2: For each found item (iterate in REVERSE order)
# CRITICAL: Reverse order prevents position shifts during replacement
foreach ($token in $tokens | Sort-Object StartLine, StartColumn -Descending) {
    
    # Step 3: Select the token's text range
    $psISE.CurrentFile.Editor.Select(
        $token.StartLine,      # Start line
        $token.StartColumn,    # Start column
        $token.EndLine,        # End line
        $token.EndColumn       # End column
    )
    
    # Step 4: Replace with new text (InsertText replaces selection)
    $psISE.CurrentFile.Editor.InsertText($replacementText)
}
```

**Key insight:** Process tokens in **reverse order** (by line/column descending) so replacements don't shift positions of earlier tokens.

---

## Tab Navigation Patterns

### Pattern 1: Get Next/Previous Tab

**From CycleISETabs.ps1:**

```powershell
# Get the collection of all PowerShell tabs
$tabs = $psISE.PowerShellTabs

# Find current tab's index
$currentIndex = $tabs.IndexOf($psISE.CurrentPowerShellTab)

# Calculate next index (with wrapping)
$nextIndex = ($currentIndex + 1) % $tabs.Count

# Activate tab
$tabs[$nextIndex].Activate()
```

**Method:** `$tab.Activate()` — Makes a tab the active tab.

### Pattern 2: Get Next File in Collection

**From Find-InFile.ps1:**

```powershell
# Get the collection
$files = $psISE.CurrentPowerShellTab.Files

# Select the last file (most recently opened)
$psISE.CurrentPowerShellTab.Files.SelectedFile = $files[-1]
```

---

## File Opening and Navigation

### Open a File (Add to Editor)

**Method:** `Open-EditorFile` cmdlet (built-in ISE function)

```powershell
Open-EditorFile -Path "C:\scripts\myfunc.ps1"
```

**Then make it active:**
```powershell
$targetFile = $psISE.CurrentPowerShellTab.Files | 
    Where-Object { $_.FullPath -eq $filePath }
$psISE.CurrentPowerShellTab.Files.SelectedFile = $targetFile
```

**Files demonstrating this:**
- Find-InFile.ps1: Opens search results, jumps to line
- Bookmarks.ps1: Opens bookmarked file, sets cursor position

### Jump to Specific Line

```powershell
# After opening file and making it active:
$psISE.CurrentPowerShellTab.Files.SelectedFile.Editor.SetCaretPosition(
    $lineNumber,   # 1-indexed
    1              # Column (start of line)
)
```

**Pattern (from Bookmarks.ps1):**
```powershell
# Open file
Open-EditorFile $bookmark.path

# Find it in collection (may have just been added)
$search = $psISE.CurrentPowerShellTab.files.where({ $_.FullPath -eq $bookmark.path })

# Make it active
$psISE.CurrentPowerShellTab.files.SelectedFile = $search[0]

# Jump to line
$search[0].editor.SetCaretPosition($bookmark.LineNumber, 1)
```

---

## Full File Access

### Read Entire File

```powershell
$allText = $psISE.CurrentFile.Editor.Text
```

**Use case:** Tokenize/parse entire file (ConvertFrom-Alias.ps1, Get-ScriptComments.ps1)

### Write Entire File

```powershell
# Clear and replace
$psISE.CurrentFile.Editor.Text = $newContent
```

**Pattern (from Reload-ISEFile.ps1):**
```powershell
# Read from disk
$disk = Get-Content -Path $psISE.CurrentFile.FullPath -Raw

# Replace editor content
$psISE.CurrentFile.Editor.Text = $disk
```

---

## Creating New Files Programmatically

### Pattern 1: Add Unsaved File to Current Tab

```powershell
$newFile = $psISE.CurrentPowerShellTab.Files.Add()
$newFile.Editor.InsertText("function MyFunc { }")
```

**Result:** New tab appears, unsaved (asterisk in tab name).

### Pattern 2: Generate Content, Insert, Display

**From New-PSCommand.ps1, New-CommentHelp.ps1:**

```powershell
# Generate content as here-string
$content = @"
#requires -version 5.1

Function MyFunction {
    ...
}
"@

# Check if ISE available
if ($UseISE -and $psISE) {
    # Create new file
    $newFile = $psISE.CurrentPowerShellTab.Files.Add()
    
    # Insert content
    $newFile.Editor.InsertText($content)
}
else {
    # Fallback: output to pipeline
    $content
}
```

**Pattern insight:** ISE detection (`if ($psISE)`) allows functions to work in both ISE and console.

---

## Snippet Integration

### Add ISE Snippet

```powershell
# From Convert-CodetoSnippet.ps1
New-IseSnippet -Title "MySnippet" -Text $snippetText -Description "..." -Author "..." -Force
```

**Method:** `New-IseSnippet` is a built-in ISE cmdlet (PowerShell 3.0+).

**Parameters:**
- `-Title`: Snippet name (shown in menu)
- `-Text`: Snippet content (with $variable placeholders for hotspot substitution)
- `-Description`: Help text
- `-Author`: Snippet author
- `-Force`: Overwrite existing

**Note:** Snippets are stored in ISE's built-in snippet library, accessible via Ctrl+J.

---

## Cursor Position and Ranges

### Line/Column Indexing

**ISE uses 1-based indexing:**
- Line 1 is first line (not line 0)
- Column 1 is first character

```powershell
# Jump to line 42, column 1 (start of line)
$editor.SetCaretPosition(42, 1)

# Jump to line 10, column 5
$editor.SetCaretPosition(10, 5)
```

### Text Ranges

```powershell
# Select from (line 10, col 1) to (line 15, col 50)
$editor.Select(10, 1, 15, 50)
```

**Pattern (from ConvertFrom-Alias.ps1):**
```powershell
# Token object has positions (1-indexed)
$editor.Select(
    $token.StartLine, 
    $token.StartColumn,
    $token.EndLine, 
    $token.EndColumn
)
```

---

## Global State and Persistence

### Accessing Global Variable (Word automation)

**From Copy-ToWord.ps1:**

```powershell
# Cache Word instance globally to maintain lifetime
if (($null -eq $global:word.Application) -OR -NOT (Get-Process WinWord)) {
    $global:word = New-Object -ComObject word.application
    $global:doc = $global:word.Documents.add()
    $global:selection = $global:word.Selection
}

# Persist state for subsequent calls
$global:selection.TypeText($text)
```

**Pattern insight:** ISE session persists global variables. Reusing cached COM objects avoids repeated initialization.

### File Persistence (Bookmarks)

**From Bookmarks.ps1:**

```powershell
# Store bookmarks in CSV file in user profile
$MyBookmarks = "$env:USERPROFILE\ise_bookmarks.csv"

# Add bookmark
$obj | Export-Csv -Path $MyBookmarks -Append -Encoding ASCII

# Retrieve bookmarks
Import-Csv $MyBookmarks | Out-GridView -OutputMode Single
```

**Pattern:** ISE functions often store state in files since ISE session may close.

---

## Error Handling and ISE Detection

### Detect ISE Availability

```powershell
# From ConvertFrom-Alias.ps1
if ($host.name -match 'ISE') {
    # ISE-specific code
}
else {
    Write-Warning 'This version only works in the PowerShell ISE'
}

# Or check $psISE directly
if ($psISE) {
    # ISE is available
}
```

**Pattern:** Functions that require ISE should validate before accessing `$psISE` objects.

### Error Recovery

```powershell
# From Bookmarks.ps1
Try {
    Import-Csv $MyBookmarks -ErrorAction Stop | Out-GridView
}
Catch {
    Write-Warning "Failed to find or import bookmarks from $($MyBookmarks)"
}
```

---

## Common Operations Summary

### "Replace all instances of X in current file"
```powershell
$text = $psISE.CurrentFile.Editor.Text
$newText = $text -replace 'pattern', 'replacement'
$psISE.CurrentFile.Editor.Text = $newText
```

### "Insert text at cursor"
```powershell
$psISE.CurrentFile.Editor.InsertText("new text")
```

### "Replace selected text"
```powershell
# Selection is already active, InsertText replaces it
$psISE.CurrentFile.Editor.InsertText("replacement")
```

### "Jump to line N"
```powershell
$psISE.CurrentFile.Editor.SetCaretPosition($n, 1)
```

### "Open file and jump to line"
```powershell
Open-EditorFile -Path $path
$file = $psISE.CurrentPowerShellTab.Files | Where-Object { $_.FullPath -eq $path }
$psISE.CurrentPowerShellTab.Files.SelectedFile = $file
$file.Editor.SetCaretPosition($lineNum, 1)
```

### "Create new file with content"
```powershell
$newFile = $psISE.CurrentPowerShellTab.Files.Add()
$newFile.Editor.InsertText($content)
```

### "Iterate all open files"
```powershell
foreach ($file in $psISE.CurrentPowerShellTab.Files) {
    $path = $file.FullPath
    $content = $file.Editor.Text
}
```

---

## Notable Limitations & Workarounds

| Challenge | Workaround | Example |
|-----------|-----------|---------|
| No built-in file close method | Use `Files.Remove($file)` | CloseAllFiles.ps1 |
| No way to select by path directly | Iterate collection with Where-Object | Find-InFile.ps1 |
| Selection coordinates don't update after insert | Process tokens in reverse order | ConvertFrom-Alias.ps1 |
| SendKeys timing is fragile | Add `Start-Sleep -Milliseconds 500` | Copy-ToWord.ps1 |
| Position tracking across edits | Store as variables, don't rely on live position | Convert-CommandToHash.ps1 |
| No programmatic snippet search | Iterate $psISE (limited metadata) | N/A |

---

## Object Model Summary

```
Read Current State:
  $psISE.CurrentFile.FullPath              # File path
  $psISE.CurrentFile.Editor.Text           # Full content
  $psISE.CurrentFile.Editor.SelectedText   # Selection
  $psISE.CurrentFile.Editor.CaretLine      # Cursor position
  $psISE.CurrentPowerShellTab.Files        # Open files

Modify Content:
  $editor.InsertText($text)                # Insert/replace at cursor
  $editor.Text = $newContent               # Replace entire file
  $editor.Select($sl,$sc,$el,$ec)         # Select range
  $editor.SetCaretPosition($line, $col)   # Move cursor

Manage Files:
  $psISE.CurrentPowerShellTab.Files.Add()  # Create new file
  $psISE.CurrentPowerShellTab.Files.Remove($file)  # Close file
  $psISE.CurrentPowerShellTab.Files.SelectedFile = $file  # Activate

Navigate:
  Open-EditorFile -Path $path             # Open file (ISE cmdlet)
  $tab.Activate()                          # Switch to tab
```

