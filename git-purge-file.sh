# Script to add a file to .gitignore and remove it from git history
# Usage: .\git-purge-file.ps1 -FilePath <file-path>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"

Write-Host "=== Git File Purge Script ===" -ForegroundColor Cyan
Write-Host "File to purge: $FilePath"
Write-Host ""

# Check if we're in a git repository
$null = git rev-parse --is-inside-work-tree 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Not inside a git repository" -ForegroundColor Red
    exit 1
}

# Get the root of the git repository
$gitRoot = git rev-parse --show-toplevel
Set-Location $gitRoot

$gitignorePath = ".gitignore"

# Step 1: Check for uncommitted changes and stash them
Write-Host "Step 1: Checking for uncommitted changes..." -ForegroundColor Yellow
$needsStash = $false
$null = git diff --quiet 2>&1
$hasDiff = $LASTEXITCODE -ne 0
$null = git diff --cached --quiet 2>&1
$hasStagedDiff = $LASTEXITCODE -ne 0

if ($hasDiff -or $hasStagedDiff) {
    $needsStash = $true
    Write-Host "  - Found uncommitted changes"
    Write-Host "  - Stashing changes (note: stash will be invalidated by history rewrite)..."
    git stash --include-untracked
} else {
    Write-Host "  - Working tree is clean"
}

# Step 2: Add file to .gitignore if not already there
Write-Host "Step 2: Adding to .gitignore..." -ForegroundColor Yellow
if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Raw -ErrorAction SilentlyContinue
    $gitignoreLines = Get-Content $gitignorePath -ErrorAction SilentlyContinue
    if ($gitignoreLines -contains $FilePath) {
        Write-Host "  - Already in .gitignore"
    } else {
        Add-Content -Path $gitignorePath -Value $FilePath
        Write-Host "  - Added to .gitignore"
    }
} else {
    Set-Content -Path $gitignorePath -Value $FilePath
    Write-Host "  - Created .gitignore and added file"
}

# Save the updated .gitignore content for restoration after filter-branch
$gitignoreContent = Get-Content $gitignorePath -Raw

# Reset .gitignore to match HEAD before filter-branch
git checkout -- $gitignorePath 2>$null

# Step 3: Remove from git cache (staging area) if currently tracked
Write-Host "Step 3: Removing from git index..." -ForegroundColor Yellow
$null = git ls-files --error-unmatch $FilePath 2>&1
if ($LASTEXITCODE -eq 0) {
    git rm --cached $FilePath 2>$null
    git checkout -- . 2>$null
    git reset HEAD 2>$null
    Write-Host "  - Removed from git index"
} else {
    Write-Host "  - File not currently tracked"
}

# Step 4: Remove from git history
Write-Host "Step 4: Removing from git history..." -ForegroundColor Yellow
Write-Host "  WARNING: This will rewrite git history!" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Do you want to remove '$FilePath' from ALL git history? (y/N)"
if ($confirm -eq 'y' -or $confirm -eq 'Y') {
    Write-Host "  - Rewriting history..."

    # Use git filter-branch to remove file from history
    $env:FILTER_BRANCH_SQUELCH_WARNING = "1"
    $filterCmd = "git rm --cached --ignore-unmatch '$FilePath'"
    git filter-branch --force --index-filter $filterCmd --prune-empty --tag-name-filter cat -- --all

    # Step 5: Clean up refs and garbage collect
    Write-Host "Step 5: Cleaning up..." -ForegroundColor Yellow
    if (Test-Path ".git/refs/original") {
        Remove-Item -Recurse -Force ".git/refs/original"
    }
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive

    # Step 6: Restore .gitignore with the file added
    Write-Host "Step 6: Restoring .gitignore..." -ForegroundColor Yellow
    Set-Content -Path $gitignorePath -Value $gitignoreContent -NoNewline
    Write-Host "  - .gitignore restored with '$FilePath' entry"

    Write-Host ""
    Write-Host "=== Complete ===" -ForegroundColor Green
    Write-Host "File '$FilePath' has been:"
    Write-Host "  - Removed from git history"
    Write-Host "  - Added to .gitignore"
    Write-Host ""
    Write-Host "NOTE: Any stashed changes were invalidated by the history rewrite." -ForegroundColor Yellow
    Write-Host "      If you had uncommitted work, you may need to redo those changes."
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review and commit the .gitignore change:"
    Write-Host "     git add .gitignore"
    Write-Host "     git commit -m 'Add $FilePath to .gitignore'"
    Write-Host ""
    Write-Host "  2. Force push to update remote (REQUIRED):" -ForegroundColor Magenta
    Write-Host "     git push origin --force --all"
    Write-Host "     git push origin --force --tags"
    Write-Host ""
    Write-Host "WARNING: All collaborators must re-clone or rebase their branches!" -ForegroundColor Red
} else {
    # Restore .gitignore since we didn't complete
    Set-Content -Path $gitignorePath -Value $gitignoreContent -NoNewline

    Write-Host "  - Skipped history rewrite"
    Write-Host ""
    Write-Host "=== Partial Complete ===" -ForegroundColor Green
    Write-Host "File '$FilePath' has been:"
    Write-Host "  - Added to .gitignore"
    Write-Host ""
    if ($needsStash) {
        Write-Host "Restoring stashed changes..."
        git stash pop
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  - Warning: Could not restore stash" -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "To commit these changes:"
    Write-Host "  git add .gitignore"
    Write-Host "  git commit -m 'Add $FilePath to .gitignore'"
}
