# Installs a section of Classic Fortress
!macro InstallSection PACKAGE DESCRIPTION
  Push ${PACKAGE}
  Push "${DESCRIPTION}"
  Call .installSection
!macroend

# Determines the size of a Classic Fortress section
!macro DetermineSectionSize PACKAGE
  ReadINIStr $0 $CFORT_INI "distfile_sizes" ${PACKAGE}
  StrCpy $SIZE $0
!macroend