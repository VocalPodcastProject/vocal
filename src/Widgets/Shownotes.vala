/***
  BEGIN LICENSE

  Copyright (C) 2014-2015 Nathan Dyer <mail@nathandyer.me>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses>

  END LICENSE
***/

using Gtk;
using Gee;
using Granite;
	namespace Vocal {

	    public class Shownotes : Gtk.ScrolledWindow {

		private WebKit.WebView webview;
		public Gtk.Button play_button;
		public Gtk.Button queue_button;
		public Gtk.Button download_button;
		public Gtk.Button share_button;
		public Gtk.Button mark_as_played_button;
		public Gtk.Button mark_as_new_button;
		public Gtk.Button delete_button;
		private Gtk.Label title_label;
		private Gtk.Label date_label;
		private Gtk.Box controls_box;

		public Shownotes () {

			var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

			this.webview = new WebKit.WebView ();
			webview.margin = 3;

			controls_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			controls_box.get_style_context().add_class("toolbar");
			controls_box.get_style_context().add_class("podcast-view-toolbar");
			controls_box.height_request = 30;

			mark_as_played_button = new Gtk.Button.from_icon_name("object-select-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			mark_as_played_button.has_tooltip = true;
			mark_as_played_button.relief = Gtk.ReliefStyle.NONE;
			mark_as_played_button.tooltip_text = _("Mark this episode as played");

			download_button = new Gtk.Button.from_icon_name("browser-download-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			download_button.has_tooltip = true;
			download_button.relief = Gtk.ReliefStyle.NONE;
			download_button.tooltip_text = _("Download episode");

			share_button = new Gtk.Button.from_icon_name("send-to-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			share_button.has_tooltip = true;
			share_button.relief = Gtk.ReliefStyle.NONE;
			share_button.tooltip_text = _("Share this episode");

			controls_box.pack_start(mark_as_played_button, false, false, 0);
			controls_box.pack_start(download_button, false, false, 0);
			controls_box.pack_end(share_button, false, false, 0);

			// Set the settings
			var settings = new WebKit.Settings();
			settings.auto_load_images = true;
			settings.default_font_family = "open-sans";
			settings.enable_smooth_scrolling = true;
			webview.settings = settings;

			title_label = new Gtk.Label("");
			title_label.get_style_context().add_class("h3");
			title_label.wrap = true;
			title_label.wrap_mode = Pango.WrapMode.WORD;
			title_label.margin_top = 20;
			title_label.margin_bottom = 6;
			title_label.margin_left = 12;
			title_label.halign = Gtk.Align.START;

			date_label = new Gtk.Label("");
			date_label.margin_bottom = 12;
			date_label.margin_left = 12;
			date_label.halign = Gtk.Align.START;

			play_button = new Gtk.Button.with_label("Play this episode");
			queue_button = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			queue_button.has_tooltip = true;
			queue_button.tooltip_text = _("Add this episode to the up next list");

			var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
			button_box.pack_start(play_button, false, false, 0);
			button_box.pack_start(queue_button, false, false, 0);
			button_box.margin_bottom = 20;
			button_box.margin_left = 12;

			var summary_label = new Gtk.Label(_("<b>Summary</b>"));
			summary_label.use_markup = true;
			summary_label.margin_left = 12;
			summary_label.margin_bottom = 6;
			summary_label.halign = Gtk.Align.START;

			content_box.pack_start(controls_box, false, false, 0);
			content_box.pack_start(title_label, false, false, 0);
			content_box.pack_start(date_label, false, false, 0);
			content_box.pack_start(button_box, false, false, 0);
			content_box.pack_start(summary_label, false, false, 0);
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

		public void set_date(GLib.DateTime date) {
			date_label.set_text(date.format("%x"));
		}
	}
}
