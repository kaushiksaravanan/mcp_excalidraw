#!/usr/bin/env pwsh
# start.ps1 — Build (if needed) and start the Excalidraw canvas + MCP servers

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Host ""
Write-Host "=== Excalidraw MCP Server ===" -ForegroundColor Cyan

# Build if dist/index.js is missing or source is newer
$needsBuild = $false
if (-not (Test-Path "$projectDir\dist\index.js")) {
    Write-Host "No build found — building now..." -ForegroundColor Yellow
    $needsBuild = $true
} else {
    $srcTime  = (Get-ChildItem "$projectDir\src" -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
    $distTime = (Get-Item "$projectDir\dist\index.js").LastWriteTime
    if ($srcTime -gt $distTime) {
        Write-Host "Source files changed — rebuilding..." -ForegroundColor Yellow
        $needsBuild = $true
    }
}

if ($needsBuild) {
    npm run build:server
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed. Exiting." -ForegroundColor Red
        exit 1
    }
    Write-Host "Build complete." -ForegroundColor Green
}

# Start canvas server (Terminal 1) in a new window
Write-Host ""
Write-Host "Starting canvas server on http://localhost:3000 ..." -ForegroundColor Green
$canvasCmd = "Set-Location '$projectDir'; `$env:HOST='0.0.0.0'; `$env:PORT='3000'; npm run canvas"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $canvasCmd -WindowStyle Normal

# Give canvas server a moment to start
Start-Sleep -Seconds 2

# Start MCP server (stdio — listens for MCP client connection)
Write-Host "Starting MCP server (stdio) ..." -ForegroundColor Green
Write-Host "  → Connect your MCP client (Claude Desktop / Cursor / etc.) to this process." -ForegroundColor Gray
Write-Host ""
$env:EXPRESS_SERVER_URL = "http://localhost:3000"
$env:ENABLE_CANVAS_SYNC = "true"
node "$projectDir\dist\index.js"
