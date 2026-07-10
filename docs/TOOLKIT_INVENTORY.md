# ISE Tools

A personal PowerShell toolkit built for the Integrated Scripting Environment (ISE). These utilities accelerate common scripting tasks through editor integration, code analysis, and automation helpers.

**Note:** PowerShell ISE is now a legacy editor. For new development, consider [VS Code with the PowerShell extension](https://code.visualstudio.com/docs/languages/powershell). However, these tools remain useful for script analysis and automation.

## Origin

These scripts are from the **ISEScriptingGeek** module, a public PowerShell toolset by Jeff Hicks (jdhitsolutions). 

**Source Repository:** [jdhitsolutions/ISEScriptingGeek on GitHub](https://github.com/jdhitsolutions/ISEScriptingGeek)

**PowerShell Gallery:** [ISEScriptingGeek](https://www.powershellgallery.com/packages/ISEScriptingGeek)

This is a well-maintained library of PowerShell ISE add-ons and utilities. While the module is no longer actively extended (as of 2019, since VS Code is Microsoft's preferred editor), it remains useful for script analysis and legacy ISE workflows.

## Quick Reference: All 31 Scripts

| Script | Category | Purpose |
|--------|----------|---------|
| **Add-ISEBookmark** | Bookmarking | Mark current cursor position with a name |
| **Bookmarks.ps1** | Bookmarking | Bookmark management system (add, open, update, remove) |
| **CIMScriptMaker.ps1** | Utilities | Generate WMI/CIM query templates |
| **CloseAllFiles.ps1** | File/Tab | Close all or all-but-current open editor tabs |
| **Convert-AliasDefinition.ps1** | Code Conversion | Expand aliases to their full command names |
| **Convert-CodetoSnippet.ps1** | Code Conversion | Convert selected code into ISE snippets |
| **Convert-CommandToHash.ps1** | Code Conversion | Extract command parameters into hash table (AST-based) |
| **Convert-ISEComment.ps1** | Code Conversion | Convert text into multi-line comment blocks |
| **ConvertAll.ps1** | Code Conversion | Batch conversion helper |
| **ConvertFrom-Alias.ps1** | Code Conversion | Scan and replace aliases in current file |
| **ConvertTo-CommentHelp.ps1** | Help/Docs | Convert comments to PowerShell help format |
| **ConvertTo-TextFile.ps1** | Export | Save ISE editor content to file |
| **Copy-ToWord.ps1** | Integration | Export selected code to Microsoft Word |
| **CurrentProjects.ps1** | Utilities | Project tracking integration |
| **CycleISETabs.ps1** | File/Tab | Navigate forward/backward through editor tabs |
| **Edit-Snippet.ps1** | Snippets | Open/edit ISE snippet library |
| **Find-InFile.ps1** | Search/Nav | Full-text search across PowerShell files with navigation |
| **Get-ASTScriptProfile.ps1** | Analysis | Comprehensive script analysis (params, functions, dependencies, help) |
| **Get-CommandMetadata.ps1** | Analysis | Extract metadata from PowerShell commands |
| **Get-ScriptComments.ps1** | Analysis | Parse and extract all comments from a script |
| **Get-SearchResult.ps1** | Search/Nav | Search utility helper |
| **New-CommentHelp.ps1** | Generation | Generate comment-based help template |
| **New-DSCResourceSnippet.ps1** | Generation | Generate Desired State Configuration resource template |
| **New-FileHere.ps1** | Utilities | Create new files at current location |
| **New-InputBox.ps1** | Utilities | GUI input dialog wrapper |
| **New-ISEFunction.ps1** | Generation | Create new function template in editor |
| **New-PSCommand.ps1** | Generation | Generate complete function skeleton with parameters and help |
| **Open-SelectedInISE.ps1** | File/Tab | Open selected file path in ISE |
| **Out-ISETab.ps1** | File/Tab | Open file or create output in new ISE tab |
| **Print-ISEFile.ps1** | Output | Print current ISE file to printer |
| **Reload-ISEFile.ps1** | File/Tab | Reload current file from disk |
| **Sign-ISEScript.ps1** | Security | Apply digital signatures to PowerShell scripts |

**Category Summary:**
- **File/Tab Management** (5): CloseAllFiles, Out-ISETab, Reload-ISEFile, Open-SelectedInISE, CycleISETabs
- **Bookmarking** (1 file, 5 functions): Navigation bookmarks
- **Code Conversion** (6): Alias expansion, parameter conversion, comment blocks, snippet creation
- **Help/Docs** (1): Help block generation
- **Analysis** (3): Script profiling, metadata extraction, comment extraction
- **Generation** (4): Function templates, help comments, DSC resources
- **Search/Navigation** (2): Full-text search, file navigation
- **Integration/Export** (2): Word export, file output, printing
- **Utilities** (4): Project tracking, CIM templates, file creation, input dialogs

## Script Categories

### File & Tab Management

- **CloseAllFiles.ps1** — Close all open editor tabs in ISE
- **Out-ISETab.ps1** — Open a file or create output in a new ISE tab
- **Reload-ISEFile.ps1** — Reload the current file from disk
- **Open-SelectedInISE.ps1** — Open the selected file path in ISE
- **CycleISETabs.ps1** — Navigate forward/backward through open tabs

### Bookmarking System

Navigation aids for jumping between frequently-used locations in scripts:

- **Bookmarks.ps1** — Complete bookmark management system
  - `Add-ISEBookmark` — Mark current cursor position with a name
  - `Get-ISEBookmark` — Display all bookmarks
  - `Open-ISEBookmark` — Jump to a bookmarked location
  - `Update-ISEBookmark` — Edit bookmark name/line
  - `Remove-ISEBookmark` — Delete a bookmark

### Code Conversion & Refactoring

Automated code transformation utilities:

- **Convert-CommandToHash.ps1** — Extract command parameters into a hash table (using AST parsing)
- **Convert-AliasDefinition.ps1** — Expand all command aliases to their full names
- **ConvertFrom-Alias.ps1** — Scan and replace aliases with expanded command names
- **Convert-CodetoSnippet.ps1** — Convert selected code block into an ISE snippet for reuse
- **Convert-ISEComment.ps1** — Convert selected text into multi-line comment blocks

### Help & Documentation Generation

Tools for creating comment-based help blocks:

- **New-CommentHelp.ps1** — Generate PowerShell comment-based help template
- **ConvertTo-CommentHelp.ps1** — Convert comment text to help format
- **Get-ScriptComments.ps1** — Extract and display all comments from a script file

### Function & Snippet Generation

Accelerate boilerplate code creation:

- **New-PSCommand.ps1** — Generate a complete function skeleton with parameters and help
- **New-ISEFunction.ps1** — Create a new function template in editor
- **New-DSCResourceSnippet.ps1** — Generate Desired State Configuration resource template
- **Edit-Snippet.ps1** — Open/edit ISE snippets

### Code Analysis & Inspection

Analyze PowerShell scripts using Abstract Syntax Tree (AST) parsing:

- **Get-ASTScriptProfile.ps1** — Comprehensive script analysis:
  - Parameter detection
  - Function/filter/alias definitions
  - Command analysis
  - Module dependencies
  - Help requirements
  - Outputs to CSV or HTML report
- **Get-CommandMetadata.ps1** — Extract metadata from PowerShell commands
- **Get-ScriptComments.ps1** — Parse and extract all comments

### Search & Navigation

Find and open code:

- **Find-InFile.ps1** — Full-text search across PowerShell files with ISE navigation
- **Get-SearchResult.ps1** — Search utility helper

### Integration & Automation

- **Copy-ToWord.ps1** — Copy selected ISE code to Microsoft Word (with optional syntax highlighting via paste)
- **CIMScriptMaker.ps1** — Generate WMI/CIM query templates for specific classes
- **New-PSCommand.ps1** — Already listed above; also supports direct ISE tab insertion
- **New-CommentHelp.ps1** — Already listed above; generates markdown-style help

### Utilities

- **New-InputBox.ps1** — Wrapper for `[Microsoft.VisualBasic.Interaction]::InputBox` (GUI input dialogs)
- **New-FileHere.ps1** — Create new files at current location
- **CurrentProjects.ps1** — Project tracking utility
- **Print-ISEFile.ps1** — Print current ISE file to printer
- **Sign-ISEScript.ps1** — Apply digital signatures to PowerShell scripts
- **ConvertAll.ps1** — Batch conversion helper

## File Statistics

- **Total Files:** 31 PowerShell scripts
- **Total Lines:** ~2,100
- **Language:** PowerShell 5.0+

## Usage Context

These scripts are designed for interactive use within PowerShell ISE:

```powershell
# Most utilities assume you're in ISE and operate on the current file/selection
$psISE.CurrentFile.Editor.SelectedText    # Selected text in editor
$psISE.CurrentFile                         # Current file object
$psISE.CurrentPowerShellTab.Files          # Open file collection
```

Load scripts into your PowerShell profile or ISE profile:
```powershell
. C:\path\to\Bookmarks.ps1
. C:\path\to\New-PSCommand.ps1
# etc.
```

Most functions are designed to operate on `$psISE` objects and will check for ISE availability.

## Migration Notes

**For modern PowerShell development:**

- Replace ISE with [VS Code + PowerShell extension](https://code.visualstudio.com/)
- Consider equivalent VS Code features for snippets and bookmarks
- Core utilities (AST parsing, alias conversion, search) remain platform-independent
- Some functions can be adapted for general PowerShell use by parameterizing the input

**Scripts that remain useful outside ISE:**
- `Get-ASTScriptProfile.ps1` — Standalone script analysis
- `ConvertFrom-Alias.ps1` — Can be modified for pipeline input
- `Get-CommandMetadata.ps1` — Platform-independent
- `Get-ScriptComments.ps1` — Platform-independent
- `CIMScriptMaker.ps1` — Standalone CIM query generation

## Project Structure

All scripts are at the root level. No dependencies or external modules required beyond Windows PowerShell built-ins.

```
ise-tools/
├── Bookmarks.ps1
├── CIMScriptMaker.ps1
├── CloseAllFiles.ps1
├── ... (28 more scripts)
└── README.md (this file)
```

## Version Information

- **PowerShell Version:** 5.1+ recommended
- **ISE Version:** Tested with PowerShell ISE included in Windows Management Framework 5.0+
- **Last Updated:** 2026-07-10 (imported to GitHub)
- **Status:** Legacy — maintained for reference; not actively developed
