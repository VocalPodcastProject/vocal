test_sources = [
        # test support
    'test_main.vala',
    'TestCase.vala',

    # test files
    'TestPodcast.vala',

    # test targets & dependencies
    meson.source_root() / 'src' / 'Objects' / 'Episode.vala',
    meson.source_root() / 'src' / 'Objects' / 'Podcast.vala',
] 


executable(
    'run_vocal_tests',
    sources: test_sources,
    dependencies: dependencies,
    install: false
)