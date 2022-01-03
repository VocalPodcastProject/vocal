/*
 * Test class for Vocal.Podcast object.
 */

public class TestPodcast : TestCase {
    
    private Vocal.Podcast podcast;
    private string _name = "podcast";

    public override string name { 
        get { return this._name; }
        set construct { this._name = value; } 
    }

    public TestPodcast () {
        Object(name:"podcast");
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