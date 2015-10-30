using Gtk;
using Gee;
using Granite;
	namespace Vocal {

	    public class Shownotes : Gtk.ScrolledWindow {

		private WebKit.WebView webview;
		public Gtk.Button play_button;
		public Gtk.Button queue_button;
		public Gtk.Button download_button;
		public Gtk.Button mark_as_played_button;
		public Gtk.Button mark_as_new_button;
		public Gtk.Button delete_button;
		private Gtk.Label title_label;

		public Shownotes () {

			var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

			this.webview = new WebKit.WebView ();

			var controls_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			controls_box.hexpand = true;

			play_button = new Gtk.Button.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            play_button.has_tooltip = true;
			play_button.relief = Gtk.ReliefStyle.NONE;
            play_button.tooltip_text = _("Play this episode immediately");

			controls_box.pack_start(play_button, false, false, 0);

			queue_button = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
			queue_button.has_tooltip = true;
			queue_button.relief = Gtk.ReliefStyle.NONE;
			queue_button.tooltip_text = _("Add this episode to the play queue");

			controls_box.pack_start(queue_button, false, false, 0);

			download_button = new Gtk.Button.from_icon_name("browser-download-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
			download_button.has_tooltip = true;
			download_button.relief = Gtk.ReliefStyle.NONE;
			download_button.tooltip_text = _("Download episode");

			controls_box.pack_end(download_button, false, false, 0);
			controls_box.margin = 5;

			// Set the settings
			/*
			var settings = new WebKit.Settings();
			settings.auto_load_images = true;
			settings.default_font_family = "open-sans";
			settings.enable_smooth_scrolling = true;
			webview.settings = settings;
			*/

			title_label = new Gtk.Label("");
			title_label.get_style_context().add_class("h3");
			title_label.wrap = true;
			title_label.wrap_mode = Pango.WrapMode.WORD;
			title_label.margin = 5;

			content_box.pack_start(controls_box, false, false, 0);
			content_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
			content_box.pack_start(title_label, false, false, 5);
			content_box.pack_start(webview, true, true, 0);

			this.add (content_box);
		}

		public void set_html(string html) {
			this.webview.load_html (Utils.get_styled_html(html), "");
			show_all();
		}

		public void show_download_button() {
			this.download_button.set_no_show_all(false);
			download_button.show();
		}

		public void hide_download_button() {
			this.download_button.set_no_show_all(true);
			download_button.hide();
		}

		public void set_title(string title) {
			title_label.set_text(title.replace("%27", "'"));
		}
	}
}
