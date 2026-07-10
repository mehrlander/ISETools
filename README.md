# ISE Tools

A personal PowerShell toolkit built for the Integrated Scripting Environment (ISE). These utilities accelerate common scripting tasks through editor integration, code analysis, and automation helpers.

**Note:** PowerShell ISE is now a legacy editor. For new development, consider [VS Code with the PowerShell extension](https://code.visualstudio.com/docs/languages/powershell). However, these tools remain useful for script analysis and automation.

## Origin

This is a collection of your own scripts written to improve productivity within PowerShell ISE. The utilities reflect professional PowerShell practices and are influenced by the PowerShell community, particularly [Jeff Hicks' work](http://jdhitsolutions.com/blog/essential-PowerShell-resources/).

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
