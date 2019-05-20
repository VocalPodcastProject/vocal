include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    ../src/Objects
    ../src/Utils
    ../src/Widgets
    ../data
    DESKTOP_FILES
        ../data/com.github.needleandthread.vocal.desktop
    APPDATA_FILES
        ../data/com.github.needleandthread.vocal.appdata.xml
)
