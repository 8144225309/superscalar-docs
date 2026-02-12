@echo off
echo.
echo  SuperScalar Docs - Local Viewer
echo  ================================
echo.
echo  Opening http://localhost:8000 in your browser...
echo  Press Ctrl+C to stop the server.
echo.
start http://localhost:8000
python -m http.server 8000
