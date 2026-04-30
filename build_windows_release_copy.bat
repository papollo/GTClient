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

echo [5/7] Generating Tibia.cwm and stripping shippable .spr files...
set "SPR_DIR=%TARGET_DIR%\data\things\1098"
set "SPR_FILE=%SPR_DIR%\Tibia.spr"
set "CWM_FILE=%SPR_DIR%\Tibia.cwm"

if not exist "%SPR_FILE%" (
    echo [ERROR] Missing source .spr for CWM conversion: %SPR_FILE%
    exit /b 1
)

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] python not found in PATH; required for tools\spr_to_cwm.py.
    exit /b 1
)

python "%SOURCE_DIR%\tools\spr_to_cwm.py" "%SPR_FILE%" "%CWM_FILE%"
if errorlevel 1 (
    echo [ERROR] spr_to_cwm.py failed.
    exit /b 1
)

if not exist "%CWM_FILE%" (
    echo [ERROR] CWM file was not produced: %CWM_FILE%
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
