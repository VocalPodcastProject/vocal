namespace Vocal {

    public class PodcastView : Gtk.ScrolledWindow {
		private Controller controller;

		private Gtk.Box container;

		public Gee.ArrayList<CoverArt> all_art;
        public Gtk.FlowBox all_flowbox;

    	public PodcastView(Controller controller) {
    		this.controller = controller;

    		container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            all_art = new Gee.ArrayList<CoverArt>();

    		all_flowbox = new Gtk.FlowBox();
            all_flowbox.get_style_context().add_class("notebook-art");
            all_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            all_flowbox.activate_on_single_click = true;
            all_flowbox.child_activated.connect(on_child_activated);
            all_flowbox.valign = Gtk.Align.START;
            all_flowbox.homogeneous = true;

		    container.add(all_flowbox);

		    add(container);
    	}

        public void on_child_activated(Gtk.FlowBoxChild child) {
            Gtk.FlowBox parent = child.parent as Gtk.FlowBox;
            CoverArt art = parent.get_child_at_index(child.get_index()).get_child() as CoverArt;
            parent.unselect_all();

            controller.window.current_episode_art = art;
            controller.highlighted_podcast = art.podcast;
            controller.window.show_details(art.podcast);
        }
    }
}