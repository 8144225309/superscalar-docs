Write-Host ""
Write-Host "  SuperScalar Docs - Local Viewer" -ForegroundColor Cyan
Write-Host "  ================================"
Write-Host ""
Write-Host "  Opening http://localhost:8000 in your browser..."
Write-Host "  Press Ctrl+C to stop the server."
Write-Host ""
Start-Process "http://localhost:8000"
python -m http.server 8000
