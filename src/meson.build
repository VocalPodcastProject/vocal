vocal_sources = [
  'Main.vala',
  'Application.vala',
  'MainWindow.vala',
  'Library.vala',
  'VocalSettings.vala',
  'config.vala',
  'Objects/DirectoryEntry.vala',
  'Objects/Episode.vala',
  'Objects/Podcast.vala',
  'Services/ImageCache.vala',
  'Utils/FeedParser.vala',
  'Utils/gpodderClient.vala',
  'Utils/iTunesProvider.vala',
  'Utils/SoupClient.vala',
  'Utils/MPRIS.vala',
  'Utils/PasswordManager.vala',
  'Utils/Player.vala',
  'Utils/Utils.vala',
  'Utils/XmlUtils.vala',
  'Widgets/AddFeedDialog.vala',
  'Widgets/CoverArt.vala',
  'Widgets/DirectoryArt.vala',
  'Widgets/DirectoryView.vala',
  'Widgets/DownloadDetailBox.vala',
  'Widgets/EpisodeDetailBox.vala',
  'Widgets/NewEpisodesView.vala',
  'Widgets/PlaybackBox.vala',
  'Widgets/PodcastView.vala',
  'Widgets/QueueBox.vala',
  'Widgets/QueueRow.vala',
  'Widgets/SearchResultBox.vala',
  'Widgets/SearchResultsView.vala',
  'Widgets/SettingsDialog.vala',
  'Widgets/Shownotes.vala',
  'Widgets/SyncDialog.vala',
  'Widgets/WelcomeScreen.vala'
]

vocal_deps = [
  dependency('libadwaita-1', version: '>= 1.0'),
  dependency('gstreamer-1.0'),
  dependency('gstreamer-player-1.0'),
  dependency('gstreamer-pbutils-1.0'),
  dependency('json-glib-1.0'),
  dependency('gee-0.8'),
  dependency('libsoup-3.0'),
  dependency('sqlite3'),
  dependency('libxml-2.0'),
  dependency('libsecret-1')
]

gnome = import('gnome')

vocal_sources += gnome.compile_resources('vocal-resources',
  'vocal.gresource.xml',
  c_name: 'vocal'
)

executable('vocal', vocal_sources,
  vala_args: '--target-glib=2.50',  dependencies: vocal_deps,
  install: true,
)
