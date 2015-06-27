project (vocal)
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share/vocal")
set (PKGDATADIR "${DATADIR}/vocal")
set (GETTEXT_PACKAGE "vocal")
set (RELEASE_NAME "Voyager")
set (VERSION "1.0")
set (VERSION_INFO "Release")
set (EXEC_NAME "vocal")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

file(GLOB_RECURSE sources src/*.vala)

# Some configuration
configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)

#GSettings
include(GSettings)
add_schema("net.launchpad.vocal.gschema.xml")

# Definitions
add_definitions ("-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\"")

# Hide C compiler warnings
add_definitions (-w)


set (BASIC_VALAC_OPTIONS
    --enable-experimental
    --disable-warnings
    --target-glib=2.32
    --thread
    -g
)

set (GLOBAL_VALAC_OPTIONS
    ${BASIC_VALAC_OPTIONS}
)

set (DEPS_PACKAGES
    clutter-gtk-1.0
    sqlite3
    gtk+-3.0
    granite
    libxml-2.0
    gstreamer-1.0
    gstreamer-pbutils-1.0
)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED libxml-2.0 granite gtk+-3.0 gstreamer-1.0 gstreamer-pbutils-1.0 gthread-2.0 sqlite3 clutter-gtk-1.0 gdk-x11-3.0)

#
# Libunity
#
pkg_check_modules (UNITY QUIET unity)
if (UNITY_FOUND)
    message ("-- libunity enabled")
    set (GLOBAL_VALAC_OPTIONS ${GLOBAL_VALAC_OPTIONS} --define=HAVE_LIBUNITY)
    set (DEPS_PACKAGES ${DEPS_PACKAGES} unity)
    set (DEPS_CFLAGS ${DEPS_CFLAGS} ${UNITY_CFLAGS})
    set (DEPS_LIBRARIES ${DEPS_LIBRARIES} ${UNITY_LIBRARIES})
    set (DEPS_LIBRARY_DIRS ${DEPS_LIBRARY_DIRS} ${UNITY_LIBRARY_DIRS})
else ()
  message ("-- libunity disabled")
endif ()

#
# Libnotify
#
pkg_check_modules (LIBNOTIFY QUIET libnotify)
if (LIBNOTIFY_FOUND)
    message ("-- libnotify enabled")
    set (GLOBAL_VALAC_OPTIONS ${GLOBAL_VALAC_OPTIONS} --define=HAVE_LIBNOTIFY)
    set (DEPS_PACKAGES ${DEPS_PACKAGES} libnotify)
    set (DEPS_CFLAGS ${DEPS_CFLAGS} ${LIBNOTIFY_CFLAGS})
    set (DEPS_LIBRARIES ${DEPS_LIBRARIES} ${LIBNOTIFY_LIBRARIES})
    set (DEPS_LIBRARY_DIRS ${DEPS_LIBRARY_DIRS} ${LIBNOTIFY_LIBRARY_DIRS})
else ()
    message ("-- libnotify disabled")
endif ()

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})


find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16.0" MINIMUM)
include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}
    src/Vocal.vala
    src/MainWindow.vala
    src/config.vala
    src/Library.vala
    src/VocalSettings.vala
    src/Objects/Podcast.vala
    src/Objects/Episode.vala
    src/Widgets/EpisodeDetailBox.vala
    src/Widgets/AddFeedDialog.vala
    src/Widgets/DownloadsPopover.vala
    src/Widgets/ShowNotesPopover.vala
    src/Widgets/PlaybackBox.vala
    src/Widgets/SettingsDialog.vala
    src/Widgets/Sidepane.vala
    src/Widgets/DownloadDetailBox.vala
    src/Widgets/CoverArt.vala
    src/Widgets/VideoControls.vala
    src/Utils/Player.vala
    src/Utils/FeedParser.vala
    src/Utils/Utils.vala
    src/Utils/MPRIS.vala
PACKAGES
    ${DEPS_PACKAGES}
OPTIONS
    ${GLOBAL_VALAC_OPTIONS}
)

add_subdirectory (po)

add_executable(${EXEC_NAME} ${VALA_C})

# uninstall target
configure_file (
    "${CMAKE_SOURCE_DIR}/cmake/Uninstall.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake"
    IMMEDIATE @ONLY)

add_custom_target (uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake)

install (TARGETS vocal RUNTIME DESTINATION bin)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/vocal.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/vocal.desktop.appdata.xml DESTINATION share/appdata/vocal.desktop.appdata.xml)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/22/vocal.svg DESTINATION share/icons/hicolor/22x22/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/24/vocal.svg DESTINATION share/icons/hicolor/24x24/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/32/vocal.svg DESTINATION share/icons/hicolor/32x32/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/48/vocal.svg DESTINATION share/icons/hicolor/48x48/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/64/vocal.svg DESTINATION share/icons/hicolor/64x64/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/128/vocal.svg DESTINATION share/icons/hicolor/128x128/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/assets/vocal-missing.png DESTINATION share/vocal)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/assets/banner.png DESTINATION share/vocal)
