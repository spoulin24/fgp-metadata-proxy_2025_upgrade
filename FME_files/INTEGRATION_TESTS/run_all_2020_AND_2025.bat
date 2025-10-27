@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM ===========================================================================
REM Master Script to Run All FME Integration Tests
REM ===========================================================================
chcp 1252 >NUL

REM --- Define Log Directory and File ---
SET "LOG_DIR=%~dp0FULL_RUN_INTEGRATION_TESTS_REPORTS"
REM Create the directory if it doesn't exist. Suppress "already exists" errors.
IF NOT EXIST "%LOG_DIR%" ( MKDIR "%LOG_DIR%" ) 2>NUL

SET "OverallExitCode=0"

REM --- Generate Timestamp ---
FOR /F "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do SET "dt=%%I"
SET "YYYY=%dt:~0,4%"
SET "MM=%dt:~4,2%"
SET "DD=%dt:~6,2%"
SET "HH=%dt:~8,2%"
SET "Min=%dt:~10,2%"
SET "Sec=%dt:~12,2%"
SET "timestamp=%YYYY%-%MM%-%DD%_%HH%%Min%%Sec%"

REM --- Create Log File (Fixed Order) ---
SET "LOG_FILE=%LOG_DIR%\fme-2020-AND-2025_integration_summary_%timestamp%.log"
ECHO Starting Integration Test Suite for FME 2020 vs 2025 Comparing with ETALON_DATA > "%LOG_FILE%"
ECHO Test run started at %YYYY%-%MM%-%DD% %HH%:%Min%:%Sec% >> "%LOG_FILE%"
ECHO ============================================ >> "%LOG_FILE%"
ECHO. >> "%LOG_FILE%"

ECHO.
ECHO ============================================
ECHO Starting Integration Test Suite for FME 2020 vs 2025
ECHO Press Ctrl+C at any time to abort
ECHO Logging to: %LOG_FILE%
ECHO ============================================
ECHO.

REM --- Check for FME Executable Variables ---
IF "%FME2020%"=="" (
    ECHO ERROR: FME2020 environment variable not set. Aborting.
    ECHO ERROR: FME2020 environment variable not set. >> "%LOG_FILE%"
    GOTO AbortTestSuite
)
IF "%FME2025%"=="" (
    ECHO ERROR: FME2025 environment variable not set. Aborting.
    ECHO ERROR: FME2025 environment variable not set. >> "%LOG_FILE%"
    GOTO AbortTestSuite
)

REM --- Loop Through Test Directories ---
FOR /D %%P IN ("%~dp0\*_PROD", "%~dp0\MB_SK_PROD_MB", "%~dp0\MB_SK_PROD_SK") DO (
    SET "ProvinceDirName=%%~nxP"
    SET "TestScriptPath=%%P\met\INTEGRATIONTEST.bat"
    SET "TestScriptDir=%%P\met"
    
    REM --- ADDED: Variables to store results ---
    SET "Result2020=Failed"
    SET "Result2025=Failed"

    ECHO.
    ECHO ###########################################################################
    ECHO ### STARTING TEST: !ProvinceDirName! ###
    ECHO ###########################################################################
    ECHO.
    ECHO "!TestScriptPath!"

    IF EXIST "!TestScriptPath!" (
        PUSHD "!TestScriptDir!"
        SET "MULTIRUN=TRUE"

        REM --- ADDED: Run 1: FME 2020 ---
        ECHO.
        ECHO --- Running !ProvinceDirName! with FME 2020 ---
        SET "FME_EXECUTABLE=%FME2020%"
        CALL INTEGRATIONTEST.bat > test_output.tmp 2>&1
        
        REM Show output
        TYPE test_output.tmp
        
        REM Check for SUCCESS message
        FINDSTR /C:"SUCCESS: All tests passed" test_output.tmp >NUL
        IF !ERRORLEVEL! EQU 0 (
            SET "Result2020=Passed"
        ) ELSE (
            SET "OverallExitCode=1"
        )

        REM --- ADDED: Run 2: FME 2025 ---
        ECHO.
        ECHO --- Running !ProvinceDirName! with FME 2025 ---
        SET "FME_EXECUTABLE=%FME2025%"
        CALL INTEGRATIONTEST.bat > test_output.tmp 2>&1
        
        REM Show output
        TYPE test_output.tmp

        REM Check for SUCCESS message
        FINDSTR /C:"SUCCESS: All tests passed" test_output.tmp >NUL
        IF !ERRORLEVEL! EQU 0 (
            SET "Result2025=Passed"
        ) ELSE (
            SET "OverallExitCode=1"
        )

        REM --- Cleanup ---
        SET "MULTIRUN="
        DEL test_output.tmp >NUL 2>&1
        POPD

        ECHO.
        ECHO --------------------------------------------
        REM --- MODIFIED: Report both results ---
        ECHO RESULT: !ProvinceDirName! - 2020: !Result2020!, 2025: !Result2025!
        ECHO !timestamp! - !ProvinceDirName!, 2020: !Result2020!, 2025: !Result2025! >> "%LOG_FILE%"
        ECHO --------------------------------------------
    ) ELSE (
        ECHO.
    )
)

ECHO.
ECHO ============================================
ECHO Test Suite Completed.
GOTO :EndSuite

:AbortTestSuite
ECHO ============================================
ECHO Test Suite Aborted.
IF %OverallExitCode% EQU 0 SET "OverallExitCode=1"

:EndSuite
ECHO ============================================
ECHO Log file: %LOG_FILE%
ECHO Final Exit Code: %OverallExitCode%
ECHO ============================================

ENDLOCAL
PAUSE
EXIT /B %OverallExitCode%