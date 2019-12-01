project (vocal)
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/vocal")
set (GETTEXT_PACKAGE "vocal")
set (RELEASE_NAME "Break a Leg")
set (VERSION "2.4.2")
set (VERSION_INFO "Release")
set (EXEC_NAME "com.github.needleandthread.vocal")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (CACHE_DIR "~/.cache/vocal")
set (USER_AGENT "vocal/${VERSION}")
set (DOLLAR "$")

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

file(GLOB_RECURSE sources src/*.vala)

# Some configuration
configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)

#GSettings
include(GSettings)
add_schema("com.github.needleandthread.vocal.gschema.xml")

include (GResource)
glib_compile_resources (GLIB_RESOURCES_VIEW SOURCE data/com.github.needleandthread.vocal.gresource.xml)

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
    webkit2gtk-4.0
    clutter-gtk-1.0
    clutter-gst-3.0
    sqlite3
    gtk+-3.0
    granite
    libxml-2.0
    libsecret-1
    gstreamer-1.0
    gstreamer-pbutils-1.0
    libsoup-2.4
    json-glib-1.0
    gee-0.8
)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED libxml-2.0 granite gtk+-3.0 gstreamer-1.0 gstreamer-pbutils-1.0 gthread-2.0 sqlite3 clutter-gtk-1.0 clutter-gst-3.0 gdk-x11-3.0 libsoup-2.4 json-glib-1.0 webkit2gtk-4.0 gee-0.8 libsecret-1)

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
ensure_vala_version("0.26.2" MINIMUM)
include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}
    src/Vocal.vala
    src/Controller.vala
    src/MainWindow.vala
    src/config.vala
    src/Library.vala
    src/VocalSettings.vala
    src/Objects/Podcast.vala
    src/Objects/Episode.vala
    src/Objects/DirectoryEntry.vala
    src/Widgets/EpisodeDetailBox.vala
    src/Widgets/AddFeedDialog.vala
    src/Widgets/DownloadsPopover.vala
    src/Widgets/ShowNotesPopover.vala
    src/Widgets/InternetArchiveUploadDialog.vala
    src/Widgets/PlaybackBox.vala
    src/Widgets/SettingsDialog.vala
    src/Widgets/DownloadDetailBox.vala
    src/Widgets/CoverArt.vala
    src/Widgets/VideoControls.vala
    src/Widgets/DirectoryView.vala
    src/Widgets/DirectoryArt.vala
    src/Widgets/NewEpisodesView.vala
    src/Widgets/CloudLoginDialog.vala
    src/Widgets/SearchResultsView.vala
    src/Widgets/PodcastView.vala
    src/Widgets/Shownotes.vala
    src/Widgets/Toolbar.vala
    src/Widgets/QueuePopover.vala
    src/Widgets/QueueRow.vala
    src/Widgets/SearchResultBox.vala
    src/Widgets/SyncDialog.vala
    src/Utils/Player.vala
    src/Utils/FeedParser.vala
    src/Utils/Utils.vala
    src/Utils/MPRIS.vala
    src/Utils/iTunesProvider.vala
    src/Utils/SoupClient.vala
    src/Utils/XmlUtils.vala
    src/Utils/gpodderClient.vala
    src/Utils/PasswordManager.vala
    src/Services/ImageCache.vala
PACKAGES
    ${DEPS_PACKAGES}
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    ${GLOBAL_VALAC_OPTIONS}
)

add_subdirectory (po)

add_executable(${EXEC_NAME} ${VALA_C} ${GLIB_RESOURCES_VIEW})

# uninstall target
configure_file (
    "${CMAKE_SOURCE_DIR}/cmake/Uninstall.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake"
    IMMEDIATE @ONLY)

add_custom_target (uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake)

install (TARGETS com.github.needleandthread.vocal RUNTIME DESTINATION bin)

#configure_file (data/com.github.needleandthread.vocal.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/com.github.needleandthread.vocal.desktop.in)
#configure_file_translation (${CMAKE_CURRENT_BINARY_DIR}/com.github.needleandthread.vocal.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/com.github.needleandthread.vocal.desktop ${CMAKE_SOURCE_DIR}/po/)
#configure_file_translation (${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.needleandthread.vocal.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/com.github.needleandthread.vocal.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.needleandthread.vocal.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.needleandthread.vocal.appdata.xml DESTINATION share/metainfo)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/16/com.github.needleandthread.vocal.svg DESTINATION share/icons/hicolor/16x16/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/22/com.github.needleandthread.vocal.svg DESTINATION share/icons/hicolor/22x22/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/24/com.github.needleandthread.vocal.svg DESTINATION share/icons/hicolor/24x24/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/32/com.github.needleandthread.vocal.svg DESTINATION share/icons/hicolor/32x32/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/48/com.github.needleandthread.vocal.svg DESTINATION share/icons/hicolor/48x48/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/64/com.github.needleandthread.vocal.svg DESTINATION share/icons/hicolor/64x64/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/128/com.github.needleandthread.vocal.svg DESTINATION share/icons/hicolor/128x128/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/scalable/com.github.needleandthread.vocal-symbolic.svg DESTINATION share/icons/hicolor/scalable/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/assets/vocal-missing.png DESTINATION share/vocal)

add_subdirectory (tests)
