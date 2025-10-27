@ECHO OFF
REM ===========================================================================
REM Generic FME Integration Test Script (Verbose  Mode)
REM ===========================================================================
SETLOCAL ENABLEDELAYEDEXPANSION

chcp 1252 >NUL
CLS
REM ===========================================================================
REM STEP 1: CONFIGURATION
REM ===========================================================================

REM --- 1. Define Dynamic Variables ---
@REM SET "FME_EXECUTABLE=C:\Program Files\fme\fme-form2025.1_b25606\fme.exe"
SET "PROVINCE_CODE=NL"
ECHO   - Configuring for PROVINCE_CODE: %PROVINCE_CODE%

REM --- NEW: Check if Etalon Base Directory exists ---
SET "ETALON_DIR_BASE=%~dp0ETALON_DATA\PT_Harvester\!PROVINCE_CODE!"

IF NOT EXIST "!ETALON_DIR_BASE!\" (
    ECHO   [ERROR] Etalon base directory not found: "!ETALON_DIR_BASE!"
    SET "Statut=!Statut!1"
    GOTO :SkipComparisons
)

ECHO ===========================================================================
ECHO Starting FME Integration Test in Verbose Mode
ECHO ===========================================================================
ECHO This script will pause after each step. Press any key to continue.
TIMEOUT /T 2  > NUL

REM --- Check for FME environment variable ---
ECHO   - Checking for FME_EXECUTABLE environment variable...
ECHO %FME_EXECUTABLE%
IF "%FME_EXECUTABLE%"=="x" (
    ECHO:
    ECHO ***************************************************************************
    ECHO ERROR: The FME_EXECUTABLE environment variable is not set.
    ECHO:
    ECHO open a Command Prompt and run this command, adjusting the path:
    ECHO:
    ECHO   setx FME_EXECUTABLE "C:\Program Files\Path\To\Your\fme.exe"
    ECHO:
    ECHO Then, CLOSE this window and run the script again in a NEW window.
    ECHO ***************************************************************************
    ECHO:
    GOTO :ErrorExit
)
ECHO   - FME Executable found at: "%FME_EXECUTABLE%"

ECHO STEP 1: CONFIGURING TEST ENVIRONMENT...
SET "test_dir=%~dp0"
SET "FME_FILES_ROOT=%test_dir%..\..\..\..\FME_files"

REM *** ATTENTION: Verify this path is correct! ***
REM The XCOPY command failed because it couldn't find this folder.
REM It resolves to: %test_dir%..\..\C_Data_TEMPLATE
SET "TEMPLATE_DIR=%test_dir%..\..\C_Data_TEMPLATE"

ECHO   - Template Directory set to: "%TEMPLATE_DIR%"
ECHO   - FME Files Root Directory set to: "%FME_FILES_ROOT%"
FOR /D %%D IN ("%test_dir%TEMP_C_DATA_*") DO (
    ECHO     - Removing: "%%~nxD"
    RMDIR /S /Q "%%D"
)
ECHO   "Old temp directories cleared"
REM --- END OF ADDED BLOCK ---

REM --- 1.A. NEW LOGIC: Set workspace and parameters based on Province ---
SET "PT_ABBR_PARAM="
SET "param_delta_finder=Yes"
SET "param_local_writer=Yes"
SET "workspace_name=%PROVINCE_CODE%_PROD.fmw"

IF /I "%PROVINCE_CODE%"=="MB" (
    SET "workspace_name=MB_SK_PROD.fmw"
    SET "PT_ABBR_PARAM=^ --P-T_ABBR "%PROVINCE_CODE%""
)
IF /I "%PROVINCE_CODE%"=="SK" (
    SET "workspace_name=MB_SK_PROD.fmw"
    SET "PT_ABBR_PARAM=^ --P-T_ABBR "%PROVINCE_CODE%""
)

SET "runner_workspace=%workspace_name%"
ECHO   - Target Workspace set to: "%runner_workspace%"
IF NOT "%PT_ABBR_PARAM%"=="" ECHO   - Adding special parameter: --P-T_ABBR "%PROVINCE_CODE%"
ECHO   - LOCAL_SOURCE_METADATA_DELTA_FINDER: %param_delta_finder%
ECHO   - LOCAL_WRITER: %param_local_writer%

REM --- 2. Generate Timestamp and Temp Path ---
FOR /F "tokens=1-4 delims=/:. " %%d in ('echo %DATE% %TIME%') do (
    SET datetime=%%d%%e%%f%%g%%h
)
@REM SET "TEMP_COPY_ROOT=.\TEMP_DATA_!datetime!"
@REM SET "FME_WORKING_DIR=!TEMP_COPY_ROOT!\PT_Harvester"

SET "TEMP_COPY_ROOT=%test_dir%TEMP_C_DATA_!datetime!"
SET "FME_WORKING_DIR=!TEMP_COPY_ROOT!\PT_Harvester"
@REM SET "TEMP_COPY_ROOT_FME=TEMP_DATA_!datetime!"
@REM SET "FME_WORKING_DIR_FME=!TEMP_COPY_ROOT_FME!\PT_Harvester"

REM --- 3. Copy Template Folder ---
XCOPY "%TEMPLATE_DIR%" "!TEMP_COPY_ROOT!\" /E /I /Y >NUL 2>&1
IF ERRORLEVEL 1 (
    ECHO ERROR: Failed to copy config template. Check path: "%TEMPLATE_DIR%"
    GOTO :ErrorExit
)
REM --- Check for FME environment variable ---
ECHO   - Checking for FME_EXECUTABLE environment variable...
IF NOT DEFINED FME_EXECUTABLE (
        ECHO ERROR: The FME_EXECUTABLE environment variable is not set.
    GOTO :ErrorExit
)
ECHO   - FME Executable found at: "%FME_EXECUTABLE%"

REM --- Define standard paths and file names ---
REM --- MODIFIED: Point runner_file to the correct FME_Workspaces directory ---
SET "runner_file=%FME_FILES_ROOT%\FME_Workspaces\%runner_workspace%"
SET "source_file=%test_dir%source1.ffs"
SET "full_temp_folder=!FME_WORKING_DIR!"
REM --- 4. Define Test-Specific Variables ---
SET "comparator_json_file=%test_dir%Comparateur_JSON.fmw"
SET "comparator_xml_file=%test_dir%Comparateur_XML.fmw"
REM --- Prepare output folder path (remove trailing backslash for FME command) ---
SET "output_folder=%test_dir%"
SET "output_folder=%output_folder:~0,-1%"

ECHO   - Script is running from:
ECHO     "%test_dir%"
ECHO   - Runner File Path set to:
ECHO     "%runner_file%"
ECHO   - Temp folder for FME will be:
ECHO     "%full_temp_folder%"
ECHO Configuration complete.
TIMEOUT /T 2  > NUL


REM ===========================================================================
REM STEP 3: CLEANUP
REM ===========================================================================

ECHO STEP 3: CLEANING UP FILES FROM PREVIOUS RUNS...
ECHO   - Deleting old 'log' files
DEL /Q "%test_dir%log_*.log" >NUL 2>&1
ECHO Cleanup complete.
TIMEOUT /T 2  > NUL

REM ===========================================================================
REM STEP 4: EXECUTE MAIN WORKSPACE
REM ===========================================================================

ECHO STEP 4: RUNNING MAIN WORKSPACE: %runner_workspace%
ECHO The following command will be executed:
ECHO "%FME_EXECUTABLE%" "%runner_file%" ^
 --ACTIVATE_GEO "Yes" ^
 --ACTIVATE_NON_GEO "Yes" ^
 --ACTIVATE_TRANSLATION "No" ^
 --CATALOGUE_READER_SELECT "No" ^
 --FORCED_PYCSW_URL "" ^
 --IN_FFS_TESTING_FILE "%source_file%" ^
 --LOCAL_SOURCE_METADATA_DELTA_FINDER "%param_delta_finder%" ^
 --LOCAL_WRITER "%param_local_writer%" ^
 --METADATA_OVERWRITE "NO" ^
 --SAMPLE_SIZE "0" ^
 --IN_OUT_WORKING_DIR "%full_temp_folder%" ^
 --URL_VALIDATION "No" ^
 --VALIDATE_INSERT_PCT_JSON "No" ^
 --VALIDATE_INSERT_PCT_XML "No" ^
 --LOG_FILE "%test_dir%log_main.log" ^
 --FME_LAUNCH_VIEWER_APP "NO" %PT_ABBR_PARAM%

TIMEOUT /T 2  > NUL

"%FME_EXECUTABLE%" "%runner_file%" ^
  --ACTIVATE_GEO "Yes" ^
  --ACTIVATE_NON_GEO "Yes" ^
  --ACTIVATE_TRANSLATION "No" ^
  --CATALOGUE_READER_SELECT "No" ^
  --FORCED_PYCSW_URL "" ^
  --IN_FFS_TESTING_FILE "%source_file%" ^
  --LOCAL_SOURCE_METADATA_DELTA_FINDER "%param_delta_finder%" ^
  --LOCAL_WRITER "%param_local_writer%" ^
  --METADATA_OVERWRITE "NO" ^
  --SAMPLE_SIZE "0" ^
  --IN_OUT_WORKING_DIR "%full_temp_folder%" ^
  --URL_VALIDATION "No" ^
  --VALIDATE_INSERT_PCT_JSON "No" ^
  --VALIDATE_INSERT_PCT_XML "No" ^
  --LOG_FILE "%test_dir%log_main.log" ^
  --FME_LAUNCH_VIEWER_APP "NO" %PT_ABBR_PARAM%

SET "Statut=%ERRORLEVEL%"
IF NOT "%Statut%"=="0" (
    ECHO ERROR: Main workspace failed with Exit Code: %Statut%
    SET "Statut=1"
    GOTO :ErrorExit
)
ECHO   - Main workspace finished with Exit Code: %Statut%

REM ===========================================================================
REM STEP 5: COMPARISON OF RESULTS
REM ===========================================================================

ECHO STEP 5: COMPARING RESULTING JSON/XML FILES

SET "RESULT_DIR_BASE=!full_temp_folder!\!PROVINCE_CODE!"

REM --- Compare JSON files ---
ECHO --- Comparing JSON files for !PROVINCE_CODE!
SET "ETALON_JSON_DIR=!ETALON_DIR_BASE!\JSON_LOCAL"
SET "RESULT_JSON_DIR=!RESULT_DIR_BASE!\JSON_LOCAL"
TIMEOUT /T 2  > NUL
REM --- NEW: Flag to track if any comparisons actually happen ---
SET "ComparisonRan=0"


REM --- Check if there are any JSON files to compare ---
IF NOT EXIST "!ETALON_JSON_DIR!\*.json" (
    ECHO   [WARN] No Etalon JSON files found in "!ETALON_JSON_DIR!\"
) ELSE (
    ECHO   Etalon JSON Dir: !ETALON_JSON_DIR!
    ECHO   Result JSON Dir: !RESULT_JSON_DIR!
    TIMEOUT /T 1  > NUL

    FOR %%F IN ("!ETALON_JSON_DIR!\*.json") DO (
        ECHO   Comparing JSON: %%~nxF
        SET "ComparisonRan=1"  REM Set flag because we found a file
        SET "ETALON_FILE=%%F"
        SET "RESULT_FILE=!RESULT_JSON_DIR!\%%~nxF"

        IF NOT EXIST "!RESULT_FILE!" (
            ECHO     ERROR: Result file not found "!RESULT_FILE!"
            SET "Statut=!Statut!1"
        ) ELSE (
            "%FME_EXECUTABLE%" "%comparator_json_file%" ^
              --ETALON_JSON "!ETALON_FILE!" ^
              --RESULTAT_JSON "!RESULT_FILE!" ^
              --KEYS_TO_IGNORE "metadata_modified, federated_date_modified" ^
              --LOG_FILE "%test_dir%log_comp_json_%%~nF.log" ^
              --FME_LAUNCH_VIEWER_APP "NO"

            SET "lastError=!ERRORLEVEL!"
            ECHO     Comparison finished - Exit Code: !lastError!
            SET "Statut=!Statut!!lastError!"
        )
    )
    ECHO   JSON comparison complete
)
TIMEOUT /T 1  > NUL

REM --- Compare XML files ---
ECHO --- Comparing XML files for !PROVINCE_CODE!
SET "ETALON_XML_DIR=!ETALON_DIR_BASE!\XML_LOCAL"
SET "RESULT_XML_DIR=!RESULT_DIR_BASE!\XML_LOCAL"

REM --- Check if there are any XML files to compare ---
IF NOT EXIST "!ETALON_XML_DIR!\*.xml" (
     ECHO   [WARN] No Etalon XML files found in "!ETALON_XML_DIR!\"
) ELSE (
    ECHO   Etalon Dir: !ETALON_XML_DIR!
    ECHO   Result Dir: !RESULT_XML_DIR!
    TIMEOUT /T 1  > NUL

    FOR %%F IN ("!ETALON_XML_DIR!\*.xml") DO (
        ECHO   Comparing XML: %%~nxF
        SET "ComparisonRan=1"  REM Set flag because we found a file
        SET "ETALON_FILE=%%F"
        SET "RESULT_FILE=!RESULT_XML_DIR!\%%~nxF"

        IF NOT EXIST "!RESULT_FILE!" (
            ECHO     ERROR: Result file not found "!RESULT_FILE!"
            SET "Statut=!Statut!1"
        ) ELSE (
            "%FME_EXECUTABLE%" "%comparator_xml_file%" ^
              --ETALON_XML "!ETALON_FILE!" ^
              --RESULTAT_XML "!RESULT_FILE!" ^
              --PATHS_TO_IGNORE "/MD_Metadata/dateStamp/Date" ^
              --LOG_FILE "%test_dir%log_comp_xml_%%~nF.log" ^
              --FME_LAUNCH_VIEWER_APP "NO"

            SET "lastError=!ERRORLEVEL!"
            ECHO     Comparison finished - Exit Code: !lastError!
            SET "Statut=!Statut!!lastError!"
        )
    )
    ECHO   XML comparison complete
)
TIMEOUT /T 2  > NUL

REM --- NEW: Check if the ComparisonRan flag was ever set ---
IF "!ComparisonRan!"=="0" (
    ECHO   [ERROR] No Etalon JSON or XML files were found to compare in "!ETALON_DIR_BASE!"
    SET "Statut=!Statut!1"
)

:SkipComparisons
ECHO Final composite status code: !Statut!

REM Check if the status string contains anything other than '0'
SET "cleanStatut=!Statut:0=!"

@IF "!cleanStatut!" EQU "" (
    @ECHO ===========================================================================
    @ECHO SUCCESS: All tests passed
    @ECHO ===========================================================================
    @COLOR A0
    @SET CodeSortie=0
    GOTO :EndScript
) ELSE (
    @ECHO ===========================================================================
    @ECHO ERROR: One or more tests failed - Check logs
    @ECHO ===========================================================================
    @COLOR CF
    @SET CodeSortie=1
    GOTO :EndScript
)

:ErrorExit
ECHO.
ECHO ***************************************************************************
ECHO * SCRIPT TERMINATED DUE TO AN ERROR
ECHO ***************************************************************************
ECHO.
SET "CodeSortie=1"
COLOR CF

:EndScript
REM ===========================================================================
REM We return the window to the starting directory
REM ===========================================================================
POPD
 
REM ===========================================================================
REM We pause so that the window does not close 
REM in case we have to double-click on the.bat to execute it.
REM ===========================================================================
COLOR
IF NOT DEFINED MULTIRUN PAUSE
EXIT /B %CodeSortie%