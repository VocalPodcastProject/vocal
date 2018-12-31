namespace Vocal {

    public class ImportView : Gtk.ScrolledWindow {

    	private Gtk.Box container;
    	
    	public ImportView(Controller controller) {
            container = new Gtk.Box(Gtk.Orientation.VERTICAL, 25);

            var import_h1_label = new Gtk.Label(_("Good Stuff is On Its Way"));
            import_h1_label.margin_top = 200;
            import_h1_label.get_style_context ().add_class("h1");

            var import_h3_label = new Gtk.Label(_("If you are importing several podcasts it can take a few minutes. Your library will be ready shortly."));
            import_h3_label.get_style_context ().add_class("h3");

            container.add(import_h1_label);
            container.add(import_h3_label);

            var spinner = new Gtk.Spinner();
            spinner.active = true;
            spinner.start();
            container.add(spinner);

            add(container);
    	}
    }
}