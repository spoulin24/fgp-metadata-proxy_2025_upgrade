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
SET "Min=%dt:~10,2%.
SET "Sec=%dt:~12,2%"
SET "timestamp=%YYYY%-%MM%-%DD%_%HH%%Min%%Sec%"

REM --- Create Log File ---
ECHO "Starting Integration Test Suite for FME 2020 Workspaces Comparing with ETALON_DATA" > "%LOG_FILE%"
SET "LOG_FILE=%LOG_DIR%\fme-2020_integration_summary_%timestamp%.log"
ECHO Test run started at %YYYY%-%MM%-%DD% %HH%:%Min%:.Sec% > "%LOG_FILE%"
ECHO ============================================ >> "%LOG_FILE%"
ECHO. >> "%LOG_FILE%"

ECHO.
ECHO ============================================
ECHO Press Ctrl+C at any time to abort
ECHO Logging to: %LOG_FILE%
ECHO ============================================
ECHO.

REM --- Loop Through Test Directories ---
FOR /D %%P IN ("%~dp0\*_PROD", "%~dp0\MB_SK_PROD_MB", "%~dp0\MB_SK_PROD_SK") DO (
    SET "ProvinceDirName=%%~nxP"
    SET "TestScriptPath=%%P\met\INTEGRATIONTEST.bat"
    SET "TestScriptDir=%%P\met"
    SET "FindResult=1" 

    ECHO.
    ECHO ###########################################################################
    ECHO ### STARTING TEST: !ProvinceDirName! ###
    ECHO ###########################################################################
    ECHO.
    ECHO "!TestScriptPath!"

    IF EXIST "!TestScriptPath!" (
        REM -- This block handles PASSED/FAILED tests --
        PUSHD "!TestScriptDir!"

        REM Set the flag so the child script knows it's being called
        SET "MULTIRUN=TRUE"
        SET "FME_EXECUTABLE=%FME2020%"
        REM Run with piped input, send output to temp file
        (ECHO.&ECHO.&ECHO.&ECHO.&ECHO.) | CALL INTEGRATIONTEST.bat > test_output.tmp 2>&1
        
        REM Unset the flag (good practice)
        SET "MULTIRUN="
        REM Show output
        TYPE test_output.tmp
        
        REM Check for SUCCESS message
        FINDSTR /C:"SUCCESS: All tests passed" test_output.tmp >NUL
        SET "FindResult=!ERRORLEVEL!"
        
        DEL test_output.tmp >NUL 2>&1
        POPD

        ECHO.
        ECHO --------------------------------------------
        IF "!FindResult!"=="0" (
            ECHO RESULT: !ProvinceDirName! - PASSED
            ECHO !timestamp! - !ProvinceDirName!, Passed >> "%LOG_FILE%"
        ) ELSE (
            ECHO RESULT: !ProvinceDirName! - FAILED
            ECHO !timestamp! - !ProvinceDirName!, Failed >> "%LOG_FILE%"
            ECHO. >> "%LOG_FILE%"

        )
        ECHO --------------------------------------------
    ) 
)

ECHO.
ECHO ============================================
ECHO Test Suite Completed Successfully.
GOTO :EndSuite

:AbortTestSuite
ECHO ============================================
ECHO Test Suite Aborted due to failure.
IF %OverallExitCode% EQU 0 SET "OverallExitCode=1"

:EndSuite
ECHO ============================================
ECHO Log file: %LOG_FILE%
ECHO Final Exit Code: %OverallExitCode%
ECHO ============================================

ENDLOCAL
PAUSE
EXIT /B %OverallExitCode%