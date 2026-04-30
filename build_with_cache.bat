@echo off
setlocal EnableExtensions EnableDelayedExpansion

for %%I in ("%~dp0.") do set "SOURCE_DIR=%%~fI"
set "BUILD_CONFIG=Release"
set "NINJA_BUILD_DIR=%SOURCE_DIR%\build\windows-release-package"
set "FALLBACK_BUILD_DIR=%SOURCE_DIR%\build\windows-release-package-msbuild"
set "TARGET_DIR=%TARGET_DIR%"
if not defined TARGET_DIR set "TARGET_DIR=C:\Users\apoll\client_files"
set "TEST_TARGET_DIR=%TEST_TARGET_DIR%"
if not defined TEST_TARGET_DIR set "TEST_TARGET_DIR=C:\Users\apoll\otclient-release-test"
set "COPIED_EXE=0"
set "USE_FALLBACK=0"

where cmake >nul 2>&1
if errorlevel 1 (
    echo [ERROR] cmake was not found in PATH.
    exit /b 1
)

if "%VCPKG_ROOT%"=="" (
    echo [ERROR] VCPKG_ROOT is not set.
    echo         Set VCPKG_ROOT before running this script.
    exit /b 1
)

where ninja >nul 2>&1
if errorlevel 1 (
    set "USE_FALLBACK=1"
    echo [INFO] Ninja not found. Falling back to Visual Studio generator.
)

echo Repo root: %SOURCE_DIR%
echo Build config: %BUILD_CONFIG%
echo Target package directory: %TARGET_DIR%
echo Test package directory: %TEST_TARGET_DIR%

if /I "%TARGET_DIR%"=="%TEST_TARGET_DIR%" (
    echo [ERROR] TARGET_DIR and TEST_TARGET_DIR must be different because init.lua is excluded from the test package.
    exit /b 1
)

if "%USE_FALLBACK%"=="0" (
    echo [1/7] Configuring windows release package build...
    cmake -S "%SOURCE_DIR%" -B "%NINJA_BUILD_DIR%" -G Ninja -D CMAKE_TOOLCHAIN_FILE="%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake" -D BUILD_STATIC_LIBRARY=ON -D VCPKG_TARGET_TRIPLET=x64-windows-static -D CMAKE_BUILD_TYPE=%BUILD_CONFIG% -D TOGGLE_BIN_FOLDER=ON
    if errorlevel 1 (
        echo [ERROR] CMake configure failed.
        exit /b 1
    )

    echo [2/7] Building windows release package...
    cmake --build "%NINJA_BUILD_DIR%" --target otclient
    if errorlevel 1 (
        echo [ERROR] CMake build failed.
        exit /b 1
    )
) else (
    echo [1/7] Configuring windows release package build with MSBuild...
    cmake -S "%SOURCE_DIR%" -B "%FALLBACK_BUILD_DIR%" -G "Visual Studio 17 2022" -A x64 -D CMAKE_TOOLCHAIN_FILE="%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake" -D BUILD_STATIC_LIBRARY=ON -D VCPKG_TARGET_TRIPLET=x64-windows-static -D CMAKE_BUILD_TYPE=%BUILD_CONFIG% -D TOGGLE_BIN_FOLDER=ON
    if errorlevel 1 (
        echo [ERROR] CMake configure failed.
        exit /b 1
    )

    echo [2/7] Building windows-release-msbuild...
    cmake --build "%FALLBACK_BUILD_DIR%" --config %BUILD_CONFIG% --target otclient
    if errorlevel 1 (
        echo [ERROR] CMake build failed.
        exit /b 1
    )
)

echo [3/7] Preparing target directory...
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
    if errorlevel 1 (
        echo [ERROR] Failed to create target directory: %TARGET_DIR%
        exit /b 1
    )
)

call :clean_dir "%TARGET_DIR%" || exit /b 1

echo [4/7] Copying client files...
call :mirror_dir "%SOURCE_DIR%\data" "%TARGET_DIR%\data" || exit /b 1
call :mirror_dir "%SOURCE_DIR%\mods" "%TARGET_DIR%\mods" || exit /b 1
call :mirror_dir "%SOURCE_DIR%\modules" "%TARGET_DIR%\modules" || exit /b 1

for %%F in (init.lua otclientrc.lua cacert.pem) do (
    if exist "%SOURCE_DIR%\%%F" (
        call :copy_file "%SOURCE_DIR%\%%F" "%TARGET_DIR%" || exit /b 1
    )
)

call :copy_runtime_files "%NINJA_BUILD_DIR%\bin" || exit /b 1
call :copy_runtime_files "%NINJA_BUILD_DIR%\bin\%BUILD_CONFIG%" || exit /b 1
call :copy_runtime_files "%NINJA_BUILD_DIR%\%BUILD_CONFIG%" || exit /b 1
call :copy_runtime_files "%FALLBACK_BUILD_DIR%\bin\%BUILD_CONFIG%" || exit /b 1
call :copy_runtime_files "%FALLBACK_BUILD_DIR%\bin" || exit /b 1
call :copy_runtime_files "%FALLBACK_BUILD_DIR%\%BUILD_CONFIG%" || exit /b 1
call :copy_runtime_files "%FALLBACK_BUILD_DIR%\Release" || exit /b 1

if "%COPIED_EXE%"=="0" (
    echo [ERROR] No otclient executable was copied. Expected Release build output was not found.
    exit /b 1
)

echo [5/7] Preparing Tibia.cwm with cache and stripping shippable .spr files...
set "SOURCE_SPR_FILE=%SOURCE_DIR%\data\things\1098\Tibia.spr"
set "SPR_DIR=%TARGET_DIR%\data\things\1098"
set "SPR_FILE=%SPR_DIR%\Tibia.spr"
set "CWM_FILE=%SPR_DIR%\Tibia.cwm"
set "CWM_CACHE_DIR=%SOURCE_DIR%\build\cwm-cache\1098"
set "CWM_CACHE_FILE=%CWM_CACHE_DIR%\Tibia.cwm"
set "CWM_HASH_FILE=%CWM_CACHE_DIR%\Tibia.spr.sha256"

if not exist "%SOURCE_SPR_FILE%" (
    echo [ERROR] Missing source .spr for CWM conversion: %SOURCE_SPR_FILE%
    exit /b 1
)

if not exist "%SPR_FILE%" (
    echo [ERROR] Missing copied .spr in target package: %SPR_FILE%
    exit /b 1
)

where powershell >nul 2>&1
if errorlevel 1 (
    echo [ERROR] powershell not found in PATH; required for CWM cache hashing.
    exit /b 1
)

if not exist "%CWM_CACHE_DIR%" (
    mkdir "%CWM_CACHE_DIR%"
    if errorlevel 1 (
        echo [ERROR] Failed to create CWM cache directory: %CWM_CACHE_DIR%
        exit /b 1
    )
)

set "SPR_HASH="
for /f "usebackq delims=" %%H in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-FileHash -LiteralPath '%SOURCE_SPR_FILE%' -Algorithm SHA256).Hash"`) do set "SPR_HASH=%%H"
if not defined SPR_HASH (
    echo [ERROR] Failed to calculate SHA256 for: %SOURCE_SPR_FILE%
    exit /b 1
)

set "CACHED_HASH="
if exist "%CWM_HASH_FILE%" (
    set /p CACHED_HASH=<"%CWM_HASH_FILE%"
)

set "NEED_CWM_REBUILD=1"
if exist "%CWM_CACHE_FILE%" (
    if /I "%SPR_HASH%"=="%CACHED_HASH%" (
        set "NEED_CWM_REBUILD=0"
    )
)

if "%NEED_CWM_REBUILD%"=="0" (
    echo       CWM cache hit. Reusing: %CWM_CACHE_FILE%
) else (
    echo       CWM cache miss. Regenerating from: %SOURCE_SPR_FILE%
    where python >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] python not found in PATH; required for tools\spr_to_cwm.py.
        exit /b 1
    )

    python "%SOURCE_DIR%\tools\spr_to_cwm.py" "%SOURCE_SPR_FILE%" "%CWM_CACHE_FILE%"
    if errorlevel 1 (
        echo [ERROR] spr_to_cwm.py failed.
        exit /b 1
    )
    > "%CWM_HASH_FILE%" echo %SPR_HASH%
)

if not exist "%CWM_CACHE_FILE%" (
    echo [ERROR] CWM cache file was not produced: %CWM_CACHE_FILE%
    exit /b 1
)

copy /Y "%CWM_CACHE_FILE%" "%CWM_FILE%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy cached CWM to: %CWM_FILE%
    exit /b 1
)

if not exist "%CWM_FILE%" (
    echo [ERROR] CWM file was not copied to target: %CWM_FILE%
    exit /b 1
)

del /Q "%SPR_FILE%"
if exist "%SPR_DIR%\Tibai.spr.bak" del /Q "%SPR_DIR%\Tibai.spr.bak"
if exist "%SPR_DIR%\Tibia.spr.bak" del /Q "%SPR_DIR%\Tibia.spr.bak"

echo [6/7] Copying test package without init.lua...
if not exist "%TEST_TARGET_DIR%" (
    mkdir "%TEST_TARGET_DIR%"
    if errorlevel 1 (
        echo [ERROR] Failed to create test target directory: %TEST_TARGET_DIR%
        exit /b 1
    )
)

robocopy "%TARGET_DIR%" "%TEST_TARGET_DIR%" /E /XF init.lua >nul
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GEQ 8 (
    echo [ERROR] robocopy failed for test package: %TEST_TARGET_DIR%
    exit /b 1
)

echo [7/7] Release package is ready.
echo Output: %TARGET_DIR%
echo Test output: %TEST_TARGET_DIR%
exit /b 0

:clean_dir
set "DIR_PATH=%~1"
if not exist "%DIR_PATH%" goto :eof
set "EMPTY_DIR=%SOURCE_DIR%\build\empty_stage"
if not exist "%EMPTY_DIR%" mkdir "%EMPTY_DIR%"
robocopy "%EMPTY_DIR%" "%DIR_PATH%" /MIR /NFL /NDL /NJH /NJS /NP >nul
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GEQ 8 (
    echo [ERROR] Failed to clean directory: %DIR_PATH%
    exit /b 1
)
exit /b 0

:copy_runtime_files
set "FROM_DIR=%~1"
if not exist "%FROM_DIR%" goto :eof
for %%F in ("%FROM_DIR%\otclient*.exe") do (
    if exist "%%~fF" (
        call :copy_file "%%~fF" "%TARGET_DIR%" || exit /b 1
        set "COPIED_EXE=1"
    )
)
for %%F in ("%FROM_DIR%\*.dll") do (
    if exist "%%~fF" (
        call :copy_file "%%~fF" "%TARGET_DIR%" || exit /b 1
    )
)
exit /b 0

:copy_file
set "FILE_PATH=%~1"
set "DEST_DIR=%~2"
if not exist "%FILE_PATH%" goto :eof
echo   - %~nx1
copy /Y "%FILE_PATH%" "%DEST_DIR%\" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy %~nx1
    exit /b 1
)
exit /b 0

:mirror_dir
set "FROM_DIR=%~1"
set "TO_DIR=%~2"

if not exist "%FROM_DIR%" (
    echo [ERROR] Missing directory: %FROM_DIR%
    exit /b 1
)

robocopy "%FROM_DIR%" "%TO_DIR%" /MIR >nul
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GEQ 8 (
    echo [ERROR] robocopy failed for %FROM_DIR%
    exit /b 1
)
exit /b 0
