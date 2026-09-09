<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/57bf593b-1a80-42d6-a2a4-5ac1baead653" />

# .files

Single repo for **Windows 11 + Linux** dotfiles. Driven by the `manifest.yaml` file.

## How to use

Requires `bun` (no external packages needed)

```powershell
# Windows
irm bun.sh/install.ps1 | iex
# Linux
curl -fsSL https://bun.sh/install | bash
```
Flags: `--dry-run`/`-d`, `--force`/`-f`, `--help`/`-h`.

# Init

```bash
git clone git@github.com:rdelian/.files.git ~/.files
bun ~/.files/bootstrap.ts
```

- For `cmd.exe` use `%userprofile%/.files`</small>
- `$DOCUMENTS` env variale resolves via `[Environment]::GetFolderPath("MyDocuments")` so it works with `OneDrive\Documents` or plain `Documents`.

## Edits

Files are **symlinks** - so you can edit either the target or repo files, in the end only the repo files are edited.

## Adding a new dotfile

1. Move file into repo: `mv ~/.config/foo ~/.files/foo`
2. Add entry to `manifest.yaml`:
   ```yaml
   links:
     - src: foo
       dest: "$HOME/.config/foo"
   ```
   Or platform-specific:
   ```yaml
   links:
     - src: foo
       dest: "%LOCALAPPDATA%/foo"
       platforms: [win32]
     - src: foo
       dest: "$HOME/.config/foo"
       platforms: [linux]
   ```
   Or multi platform:
   ```yaml
   links:
     - src: nvim
       dest: "$HOME/.config/nvim"
       platforms: [linux, darwin]
   ```

## Notes
- **Admin**: Windows symlinks need elevation or Developer Mode. `bun bootstrap.ts --force` tries anyway; `--dry-run` safe.
- **Backups**: existing files moved to `*.bak-YYYYMMDD-HHmmss`, not deleted.

## Run example:
```bash
# Test run #
C:\Users\rdelian\.files>bun bootstrap.ts -d
RepoRoot: C:\Users\rdelian\.files
[DRY RUN] no changes
Documents: C:\Users\rdelian\OneDrive\Documents
[DRY] mklink C:\Users\rdelian\AppData\Local\nvim -> C:\Users\rdelian\.files\nvim
skip nvim -> $HOME/.config/nvim (not win32)
[DRY] mkdir C:\Users\rdelian\.config\wezterm
[DRY] mklink C:\Users\rdelian\.config\wezterm\wezterm.lua -> C:\Users\rdelian\.files\wezterm\wezterm.lua
ok   C:\Users\rdelian\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -> C:\Users\rdelian\.files\powershell\Microsoft.PowerShell_profile.ps1
ok   C:\Users\rdelian\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1 -> C:\Users\rdelian\.files\powershell\Microsoft.PowerShell_profile.ps1

Done. Processed 4 links.
Dry run - re-run without --dry-run

# Real run #
C:\Users\rdelian\.files>bun bootstrap.ts
RepoRoot: C:\Users\rdelian\.files
Documents: C:\Users\rdelian\OneDrive\Documents
link C:\Users\rdelian\AppData\Local\nvim -> C:\Users\rdelian\.files\nvim
skip nvim -> $HOME/.config/nvim (not win32)
link C:\Users\rdelian\.config\wezterm\wezterm.lua -> C:\Users\rdelian\.files\wezterm\wezterm.lua
ok   C:\Users\rdelian\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -> C:\Users\rdelian\.files\powershell\Microsoft.PowerShell_profile.ps1
ok   C:\Users\rdelian\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1 -> C:\Users\rdelian\.files\powershell\Microsoft.PowerShell_profile.ps1

Done. Processed 4 links.

# Simulate run on linux #
C:\Users\rdelian\.files>wsl
debian@rdelian:/mnt/c/Users/rdelian/.files$ bun bootstrap.ts
RepoRoot: /mnt/c/Users/rdelian/.files
skip nvim -> %LOCALAPPDATA%/nvim (not linux)
link /home/debi/.config/nvim -> /mnt/c/Users/rdelian/.files/nvim
link /home/debi/.config/wezterm/wezterm.lua -> /mnt/c/Users/rdelian/.files/wezterm/wezterm.lua
skip powershell/Microsoft.PowerShell_profile.ps1 -> $DOCUMENTS/WindowsPowerShell/Microsoft.PowerShell_profile.ps1 (not linux)
skip powershell/Microsoft.PowerShell_profile.ps1 -> $DOCUMENTS/PowerShell/Microsoft.PowerShell_profile.ps1 (not linux)

Done. Processed 2 links.
debian@rdelian:/mnt/c/Users/rdelian/.files$
```
