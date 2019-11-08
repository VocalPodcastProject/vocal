# Build tests
# Based on example project: github.com/flplv/vala-cmake-example

set (TEST_EXEC_NAME run_vocal_tests)

set (VOCAL_UNIT_TESTS_VALA_SOURCES
    # test support
    test_main.vala
    TestCase.vala

    # test files
    TestPodcast.vala

    # test targets & dependencies
    ../src/Objects/Episode.vala
    ../src/Objects/Podcast.vala
)

vala_precompile (VOCAL_UNIT_TESTS_C_SOURCES ${TEST_EXEC_NAME}
    ${VOCAL_UNIT_TESTS_VALA_SOURCES}
PACKAGES
    ${DEPS_PACKAGES}
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    ${GLOBAL_VALAC_OPTIONS}
)

message (${TEST_EXEC_NAME})
message (${VOCAL_UNIT_TESTS_C_SOURCES})

add_executable(${TEST_EXEC_NAME}
    ${VOCAL_UNIT_TESTS_C_SOURCES}
)
