namespace Vocal {

    public class WelcomeView : Gtk.Box {

    	private const int SHOW_STORE = 0;
    	private const int ADD_FEED = 1;
    	private const int IMPORT_OPML = 2;

    	private Controller controller;

    	public WelcomeView(Controller controller) {
    		this.controller = controller;

            var welcome = new Granite.Widgets.Welcome (_("Welcome to Vocal"), _("Build Your Library By Adding Podcasts"));

            welcome.append(controller.on_elementary ? "preferences-desktop-online-accounts" : "applications-internet", _("Browse Podcasts"),
                 _("Browse through podcasts and choose some to add to your Library."));

            welcome.append("list-add", _("Add a New Feed"), _("Provide the web address of a podcast feed."));
            welcome.append("document-open", _("Import Subscriptions"),
                _("If you have exported feeds from another podcast manager, import them here."));
            welcome.activated.connect(on_welcome);

            add(welcome);
    	}

        private void on_welcome(int index) {

        	switch (index) {
        	case SHOW_STORE:
	            controller.window.switch_visible_page(controller.window.directory);

	            // Set the controller.library as the previous widget for return_to_library to work
	            controller.window.previous_widget = controller.window.podcast_view;
	            break;
			case ADD_FEED:
	            controller.window.add_new_podcast();
	            break;
			case IMPORT_OPML:
	            controller.window.import_podcasts();
	            break;
	        default:
	        	warning("Unexpected option \"%d\" in welcome view", index);
	        	break;
	        }
        }
    }
}