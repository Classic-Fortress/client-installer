;Classic Fortress Client Installer Script

Name "Classic Fortress"
OutFile "Binaries\cfortress.exe"
InstallDir "C:\Classic Fortress"

# Editing anything below this line is not recommended
;---------------------------------------------------
;Header Files

!include "MUI.nsh"
!include "FileFunc.nsh"
!insertmacro GetSize
!insertmacro GetTime
!include "LogicLib.nsh"
!include "Time.nsh"
!include "Locate.nsh"
!include "WinMessages.nsh"
!include "MultiUser.nsh"
!include "cfort-macros.nsh"

;----------------------------------------------------
;Variables

Var DISTFILES_URL
Var ERRLOG
Var ERRLOGTMP
Var ERRORS
Var INSTALLED
Var INSTSIZE
Var CFORT_INI
Var RETRIES
Var SIZE

;----------------------------------------------------
;Interface Settings

!define MUI_HEADERIMAGE

!define MULTIUSER_EXECUTIONLEVEL Highest

;----------------------------------------------------
;Installer Pages

!define MUI_PAGE_CUSTOMFUNCTION_PRE "WelcomeShow"
!define MUI_WELCOMEPAGE_TITLE "Classic Fortress Installation Wizard"
!insertmacro MUI_PAGE_WELCOME

LicenseForceSelection checkbox "I agree to these terms and conditions"
!insertmacro MUI_PAGE_LICENSE "license.txt"

DirText "Setup will install Classic Fortress in the following folder. To install in a different folder, click Browse and select another folder. Click Next to continue.$\r$\n$\r$\nIt is NOT ADVISABLE to install in the Program Files folder." "Destination Folder" "Browse" "Select the folder to install Classic Fortress in:"
!define MUI_PAGE_CUSTOMFUNCTION_SHOW DirectoryPageShow
!insertmacro MUI_PAGE_DIRECTORY

Page custom DOWNLOAD

ShowInstDetails "nevershow"
!insertmacro MUI_PAGE_INSTFILES

Page custom ERRORS

!define MUI_PAGE_CUSTOMFUNCTION_SHOW "FinishShow"
!define MUI_FINISHPAGE_RUN "$INSTDIR\ezfortress.exe"
!define MUI_FINISHPAGE_LINK "Get started with Classic Fortress"
!define MUI_FINISHPAGE_LINK_LOCATION "https://github.com/Classic-Fortress/client-installer/wiki"
!define MUI_FINISHPAGE_NOREBOOTSUPPORT
!insertmacro MUI_PAGE_FINISH

;----------------------------------------------------
;Languages

!insertmacro MUI_LANGUAGE "English"

;----------------------------------------------------
;NSIS Manipulation

LangString ^Branding ${LANG_ENGLISH} "Classic Fortress Client Installer"
LangString ^SetupCaption ${LANG_ENGLISH} "Classic Fortress Client Installer"
LangString ^SpaceRequired ${LANG_ENGLISH} "Download size: "

;----------------------------------------------------
;Reserve Files

ReserveFile "mirrorselect.ini"
ReserveFile "errors.ini"

!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS

;----------------------------------------------------
;Installer Sections

Section "" # Prepare installation

  SetOutPath $INSTDIR

  # Set progress bar
  RealProgress::SetProgress /NOUNLOAD 0

  # Calculate the installation size
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "qsw106.zip"
  IntOp $INSTSIZE $INSTSIZE + $0
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "cfort-gpl.zip"
  IntOp $INSTSIZE $INSTSIZE + $0
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "cfort-non-gpl.zip"
  IntOp $INSTSIZE $INSTSIZE + $0

  # Find out what mirror was selected
  !insertmacro MUI_INSTALLOPTIONS_READ $R0 "mirrorselect.ini" "Field 3" "State"
  ${If} $R0 == "Randomly selected mirror (Recommended)"
    # Get amount of mirrors ($0 = amount of mirrors)
    StrCpy $0 1
    ReadINIStr $1 $CFORT_INI "mirror_descriptions" $0
    ${DoUntil} $1 == ""
      ReadINIStr $1 $CFORT_INI "mirror_descriptions" $0
      IntOp $0 $0 + 1
    ${LoopUntil} $1 == ""
    IntOp $0 $0 - 2
  
    # Get time (seconds)
    ${time::GetLocalTime} $1
    StrCpy $1 $1 "" -2
    
    # Fix seconds (00 -> 1, 01-09 -> 1-9)
    ${If} $1 == "00"
      StrCpy $1 1
    ${Else}
      StrCpy $2 $1 1 -2
      ${If} $2 == 0
        StrCpy $1 $1 1 -1
      ${EndIf}
    ${EndIf}
  
    # Loop until you get a number that's within the range 0 < x =< $0
    ${DoUntil} $1 <= $0
      IntOp $1 $1 - $0
    ${LoopUntil} $1 <= $0
    ReadINIStr $DISTFILES_URL $CFORT_INI "mirror_addresses" $1
    ReadINIStr $0 $CFORT_INI "mirror_descriptions" $1
  ${Else}
    ${For} $0 1 1000
      ReadINIStr $R1 $CFORT_INI "mirror_descriptions" $0
      ${If} $R0 == $R1
        ReadINIStr $DISTFILES_URL $CFORT_INI "mirror_addresses" $0
        ReadINIStr $0 $CFORT_INI "mirror_descriptions" $0
        ${ExitFor}
      ${EndIf}
    ${Next}
  ${EndIf}

  # Open temporary files
  GetTempFileName $ERRLOGTMP
  FileOpen $ERRLOG $ERRLOGTMP a

SectionEnd

Section "Classic Fortress" CFORT

  # Download and install pak0.pak (shareware data)
  !insertmacro InstallSection qsw106.zip "Quake shareware"
  # Remove crap files extracted from shareware zip and rename uppercase files/folders
  Delete "$INSTDIR\CWSDPMI.EXE"
  Delete "$INSTDIR\QLAUNCH.EXE"
  Delete "$INSTDIR\QUAKE.EXE"
  Delete "$INSTDIR\GENVXD.DLL"
  Delete "$INSTDIR\QUAKEUDP.DLL"
  Delete "$INSTDIR\PDIPX.COM"
  Delete "$INSTDIR\Q95.BAT"
  Delete "$INSTDIR\COMEXP.TXT"
  Delete "$INSTDIR\HELP.TXT"
  Delete "$INSTDIR\LICINFO.TXT"
  Delete "$INSTDIR\MANUAL.TXT"
  Delete "$INSTDIR\ORDER.TXT"
  Delete "$INSTDIR\README.TXT"
  Delete "$INSTDIR\READV106.TXT"
  Delete "$INSTDIR\SLICNSE.TXT"
  Delete "$INSTDIR\TECHINFO.TXT"
  Delete "$INSTDIR\MGENVXD.VXD"
  # Move pak0.pak into place
  ${If} ${FileExists} "$INSTDIR\qw\pak0.pak"
    Delete "$INSTDIR\qw\pak0.pak"
  ${EndIf}
  CreateDirectory "$INSTDIR\qw"
  Rename "$INSTDIR\ID1\PAK0.PAK" "$INSTDIR\qw\pak0.pak"
  RMDir "$INSTDIR\ID1"
  # Add to installed size
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "qsw106.zip"
  IntOp $INSTALLED $INSTALLED + $0
  # Set progress bar
  IntOp $0 $INSTALLED * 100
  IntOp $0 $0 / $INSTSIZE
  RealProgress::SetProgress /NOUNLOAD $0

  # Download and install client files
  !insertmacro InstallSection cfort-gpl.zip "client files"
  # Add to installed size
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "cfort-gpl.zip"
  IntOp $INSTALLED $INSTALLED + $0
  # Set progress bar
  IntOp $0 $INSTALLED * 100
  IntOp $0 $0 / $INSTSIZE
  RealProgress::SetProgress /NOUNLOAD $0

  # Download and install non-GPL files
  !insertmacro InstallSection cfort-non-gpl.zip "Team Fortress game files"
  # Add to installed size
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "cfort-non-gpl.zip"
  IntOp $INSTALLED $INSTALLED + $0
  # Set progress bar
  IntOp $0 $INSTALLED * 100
  IntOp $0 $0 / $INSTSIZE
  RealProgress::SetProgress /NOUNLOAD $0

  # Download configuration files
  Call .installConfigs

SectionEnd

Section "" # Clean up installation

  # Close open temporary files
  FileClose $ERRLOG

SectionEnd

;----------------------------------------------------
;Custom Pages

Function DOWNLOAD

  !insertmacro MUI_INSTALLOPTIONS_EXTRACT "mirrorselect.ini"
  !insertmacro MUI_HEADER_TEXT "Setup Files" "Select a mirror."

  # Fix the mirrors for the Preferences page
  StrCpy $0 1
  StrCpy $2 "Randomly selected mirror (Recommended)"
  ReadINIStr $1 $CFORT_INI "mirror_descriptions" $0
  ${DoUntil} $1 == ""
    ReadINIStr $1 $CFORT_INI "mirror_descriptions" $0
    ${Unless} $1 == ""
      StrCpy $2 "$2|$1"
    ${EndUnless}
    IntOp $0 $0 + 1
  ${LoopUntil} $1 == ""

  StrCpy $0 $2 3
  ${If} $0 == "|"
    StrCpy $2 $2 "" 1
  ${EndIf}

  !insertmacro MUI_INSTALLOPTIONS_WRITE "mirrorselect.ini" "Field 3" "ListItems" $2
  !insertmacro MUI_INSTALLOPTIONS_DISPLAY "mirrorselect.ini"

FunctionEnd

Function ERRORS

  # Only display error page if errors occured during installation
  ${If} $ERRORS > 0
    # Read errors from error log
    StrCpy $1 ""
    FileOpen $R0 $ERRLOGTMP r
      ClearErrors
      FileRead $R0 $0
      StrCpy $1 $0
      ${DoUntil} ${Errors}
        FileRead $R0 $0
        ${Unless} $0 == ""
          StrCpy $1 "$1|$0"
        ${EndUnless}
      ${LoopUntil} ${Errors}
    FileClose $R0

    !insertmacro MUI_INSTALLOPTIONS_EXTRACT "errors.ini"
    ${If} $ERRORS == 1
      !insertmacro MUI_HEADER_TEXT "Error" "An error occurred during the installation of Classic Fortress."
      !insertmacro MUI_INSTALLOPTIONS_WRITE "errors.ini" "Field 1" "Text" "There was an error during the installation of Classic Fortress. See below for more information."
    ${Else}
      !insertmacro MUI_HEADER_TEXT "Errors" "Some errors occurred during the installation of Classic Fortress."
      !insertmacro MUI_INSTALLOPTIONS_WRITE "errors.ini" "Field 1" "Text" "There were some errors during the installation of Classic Fortress. See below for more information."
    ${EndIf}
    !insertmacro MUI_INSTALLOPTIONS_WRITE "errors.ini" "Field 2" "ListItems" $1
    !insertmacro MUI_INSTALLOPTIONS_DISPLAY "errors.ini"
  ${EndIf}

FunctionEnd

;----------------------------------------------------
;Welcome/Finish page manipulation

Function WelcomeShow
  !insertmacro MUI_INSTALLOPTIONS_WRITE "ioSpecial.ini" "Field 3" "Text" "This is the installation wizard of Classic Fortress, the authentic Team Fortress experience.\r\n\r\nThis is an online installer and therefore requires a stable internet connection. This installer and game is portable and will therefore not touch your registry or install start menu items."
FunctionEnd

Function FinishShow
  # Hide the Back button on the finish page if there were no errors
  ${Unless} $ERRORS > 0
    GetDlgItem $R0 $HWNDPARENT 3
    EnableWindow $R0 0
  ${EndUnless}
FunctionEnd

;----------------------------------------------------
;Download size manipulation

!define SetSize "Call SetSize"

Function SetSize
  IntOp $1 0 + 0
  !insertmacro DetermineSectionSize qsw106.zip
  IntOp $1 $1 + $SIZE
  !insertmacro DetermineSectionSize cfort-gpl.zip
  IntOp $1 $1 + $SIZE
  !insertmacro DetermineSectionSize cfort-non-gpl.zip
  IntOp $1 $1 + $SIZE
FunctionEnd

Function DirectoryPageShow
  ${SetSize}
  SectionSetSize ${CFORT} $1
FunctionEnd 

;----------------------------------------------------
;Functions

Function .onInit

  !insertmacro MULTIUSER_INIT
  GetTempFileName $CFORT_INI

  # Download cfort.ini
  Start:
  inetc::get /NOUNLOAD /CAPTION "Initializing..." /BANNER "Classic Fortress is initializing, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-installer/master/cfort.ini" $CFORT_INI /END
  Pop $0
  ${Unless} $0 == "OK"
    ${If} $0 == "Cancelled"
      MessageBox MB_OK|MB_ICONEXCLAMATION "Installation aborted."
      Abort
    ${Else}
      ${Unless} $RETRIES == 2
        MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Could not download cfort.ini." IDCANCEL Cancel
        IntOp $RETRIES $RETRIES + 1
        Goto Start
      ${EndUnless}
      MessageBox MB_OK|MB_ICONEXCLAMATION "Could not download cfort.ini. Please try again later."
      Cancel:
      Abort
    ${EndIf}
  ${EndUnless}

FunctionEnd

Function .abortInstallation

  # Close open temporary files
  FileClose $ERRLOG

  # Ask to remove installed files
  Messagebox MB_YESNO|MB_ICONEXCLAMATION "Installation aborted.$\r$\n$\r$\nDo you wish to remove the installed files?" IDNO SkipInstRemoval
  # Show details window
  SetDetailsView show
  RMDir /r $INSTDIR
  SkipInstRemoval:

  # Set progress bar to 100%
  RealProgress::SetProgress /NOUNLOAD 100

  Abort

FunctionEnd

Function .installConfigs
  StrCpy $0 "fortress\default.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading configuration files, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
FunctionEnd

Function .installDistfile
  GetTempFileName $1
  Retry:
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading $R1, please wait..." /TIMEOUT 5000 "$DISTFILES_URL/$R0" "$1" /END
  Pop $0
  ${Unless} $0 == "OK"
    ${If} $0 == "Cancelled"
      Call .abortInstallation
    ${Else}
      MessageBox MB_ABORTRETRYIGNORE|MB_ICONEXCLAMATION "Error downloading $R0: $0" IDIGNORE Ignore IDRETRY Retry
      Call .abortInstallation
      Ignore:
      FileWrite $ERRLOG 'Error downloading "$R0": $0|'
      IntOp $ERRORS $ERRORS + 1
    ${EndIf}
  ${EndUnless}
  DetailPrint "Extracting $R1, please wait..."
  nsisunz::UnzipToStack "$1" $INSTDIR
  Pop $0
  ${If} $0 == "Error opening ZIP file"
  ${OrIf} $0 == "Error opening output file(s)"
  ${OrIf} $0 == "Error writing output file(s)"
  ${OrIf} $0 == "Error extracting from ZIP file"
  ${OrIf} $0 == "File not found in ZIP file"
    FileWrite $ERRLOG 'Error extracting "$R0": $0|'
    IntOp $ERRORS $ERRORS + 1
  ${EndIf}
  Delete "$1"
FunctionEnd

Function .installSection
  Pop $R1 # distfile info
  Pop $R0 # distfile filename
  Call .installDistfile
FunctionEnd