/*
 * Test runner entry method.
 */
int main (string[] args) {
    Test.init (ref args);

    /*
     * Add test suites here.
     */

    TestSuite.get_root ().add_suite (new TestPodcast ().get_suite ());

    return Test.run ();
}