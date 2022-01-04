project('com.github.needleandthread.vocal', 'vala', 'c', version: '2.4.2', meson_version: '>=0.53.2')
meson.add_install_script('meson/post_install.py')

ssmod = import('sourceset')
i18n = import('i18n')
gnome = import('gnome')

config = {
    'DATADIR': get_option('datadir'),
    'PKGDATADIR': get_option('datadir') + '/vocal',
    'GETTEXT_PACKAGE': 'vocal',
    'RELEASE_NAME': 'Break a Leg v2',
    'VERSION': meson.project_version(),
    'VERSION_INFO': 'Release',
    'CACHE_DIR': '~/.cache/vocal',
    'USER_AGENT': 'vocal/' + meson.project_version(),
}

gresource = gnome.compile_resources(
    'gresource',
    'data' / 'com.github.needleandthread.vocal.gresource.xml',
    source_dir: 'data'
)

vapi_dir = meson.current_source_dir() / 'vapi'

add_global_arguments([
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    '-w',
], language: 'c')

add_global_arguments([
    '--vapidir', vapi_dir,
    '--enable-experimental',
    '--disable-warnings',
    '--target-glib=2.32',
    '--thread',
    '-g',
    '--save-temps'
], language: 'vala')

subdir('src')

src = [
    gresource,
    'src' / 'config.vala',
    'src' / 'Controller.vala',
    'src' / 'Library.vala',
    'src' / 'MainWindow.vala',
    'src' / 'Objects' / 'DirectoryEntry.vala',
    'src' / 'Objects' / 'Episode.vala',
    'src' / 'Objects' / 'Podcast.vala',
    'src' / 'Services' / 'ImageCache.vala',
    'src' / 'Utils' / 'FeedParser.vala',
    'src' / 'Utils' / 'gpodderClient.vala',
    'src' / 'Utils' / 'iTunesProvider.vala',
    'src' / 'Utils' / 'MPRIS.vala',
    'src' / 'Utils' / 'PasswordManager.vala',
    'src' / 'Utils' / 'Player.vala',
    'src' / 'Utils' / 'SoupClient.vala',
    'src' / 'Utils' / 'Utils.vala',
    'src' / 'Utils' / 'XmlUtils.vala',
    'src' / 'Vocal.vala',
    'src' / 'VocalSettings.vala',
    'src' / 'Widgets' / 'AddFeedDialog.vala',
    'src' / 'Widgets' / 'ArtworkPopover.vala',
    'src' / 'Widgets' / 'CoverArt.vala',
    'src' / 'Widgets' / 'DirectoryArt.vala',
    'src' / 'Widgets' / 'DirectoryView.vala',
    'src' / 'Widgets' / 'DownloadDetailBox.vala',
    'src' / 'Widgets' / 'DownloadsPopover.vala',
    'src' / 'Widgets' / 'EpisodeDetailBox.vala',
    'src' / 'Widgets' / 'InternetArchiveUploadDialog.vala',
    'src' / 'Widgets' / 'NewEpisodesView.vala',
    'src' / 'Widgets' / 'PlaybackBox.vala',
    'src' / 'Widgets' / 'PodcastView.vala',
    'src' / 'Widgets' / 'QueueBox.vala',
    'src' / 'Widgets' / 'QueueRow.vala',
    'src' / 'Widgets' / 'SearchResultBox.vala',
    'src' / 'Widgets' / 'SearchResultsView.vala',
    'src' / 'Widgets' / 'SettingsDialog.vala',
    'src' / 'Widgets' / 'Shownotes.vala',
    'src' / 'Widgets' / 'SyncDialog.vala',
    'src' / 'Widgets' / 'Toolbar.vala',
    'src' / 'Widgets' / 'VideoControls.vala',
]

dependencies = [
    dependency('clutter-gst-3.0'),
    dependency('clutter-gtk-1.0'),
    dependency('gee-0.8'),
    dependency('granite'),
    dependency('gstreamer-1.0'),
    dependency('gstreamer-pbutils-1.0'),
    dependency('gtk+-3.0'),
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('json-glib-1.0'),
    dependency('libsecret-1'),
    dependency('libsoup-2.4'),
    dependency('libxml-2.0'),
    dependency('sqlite3'),
    dependency('webkit2gtk-4.0'),
    dependency('unity', required: false),
    dependency('libnotify', required: false),
    # meson.get_compiler('vala').find_library('webkit2gtk-3.0', dirs: vapi_dir)
]

i18n.merge_file(
    input: 'data' / 'com.github.needleandthread.vocal.desktop.in',
    output: meson.project_name() + '.desktop',
    po_dir: 'po',
    type: 'desktop',
    install: true,
    install_dir: get_option('datadir') / 'applications',
)

i18n.merge_file(
    input: 'data' / 'com.github.needleandthread.vocal.appdata.xml.in',
    output: meson.project_name() + '.appdata.xml',
    po_dir: 'po',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)

icon_sizes = ['16', '22', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        'icons' / i / 'com.github.needleandthread.vocal.svg',
        install_dir: get_option('datadir') / 'icons' / 'hicolor' / i + 'x' + i / 'apps',
    )

    install_data(
        'icons' / i / 'com.github.needleandthread.vocal.svg',
        install_dir: get_option('datadir') / 'icons' / 'hicolor' / i + 'x' + i + '@2' / 'apps',
    )
endforeach

install_data(
    'icons' / 'scalable'/ 'com.github.needleandthread.vocal-symbolic.svg',
    install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
)

install_data(
    'icons' / 'assets'/ 'vocal-missing.png',
    install_dir: get_option('datadir') / 'share' / 'vocal',
)

subdir('data')
subdir('po')
subdir('tests')

executable(
    meson.project_name(),
    sources: src,
    dependencies: dependencies,
    install: true
)
