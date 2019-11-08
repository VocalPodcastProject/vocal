/*
 * Test class for Vocal.Podcast object.
 */

public class TestPodcast : TestCase {
    
    private Vocal.Podcast podcast;

    public TestPodcast () {
        base ("podcast");
        add_test ("instantiation", test_inst);
        add_test ("name_empty", test_name_empty);
    }

    public override void set_up () {
        this.podcast = new Vocal.Podcast ();
    }

    public override void tear_down () {
    }

    public void test_inst () {
        assert (this.podcast != null);
        assert (this.podcast.name == "");
    }

    public void test_name_empty () {
        // empty podcast name should be empty string, not null
        assert (this.podcast.name == "");
    }
}