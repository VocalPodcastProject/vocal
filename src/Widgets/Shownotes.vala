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

    	public signal void copy_shareable_link();
    	public signal void send_tweet();
    	public signal void copy_direct_link();

		public Gtk.Button play_button;
		public Gtk.Button queue_button;
		public Gtk.Button download_button;
		public Gtk.Button share_button;
		public Gtk.Button mark_as_played_button;
		public Gtk.Button mark_as_new_button;
		public Gtk.Button delete_button;
		public Episode episode = null;

		public Gtk.MenuItem shareable_link;
		public Gtk.MenuItem tweet;
		public Gtk.MenuItem link_to_file;

		private Gtk.Label title_label;
		private Gtk.Label date_label;
		private Gtk.Box controls_box;
		private Gtk.Label shownotes_label;

		public Shownotes () {

			var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

			shownotes_label = new Gtk.Label ("");
			shownotes_label.margin = 12;
			shownotes_label.halign = Gtk.Align.START;
			shownotes_label.valign = Gtk.Align.START;
			shownotes_label.xalign = 0;
			shownotes_label.wrap = true;

			controls_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			controls_box.get_style_context().add_class("toolbar");
			controls_box.get_style_context().add_class("podcast-view-toolbar");
			controls_box.height_request = 30;

			mark_as_played_button = new Gtk.Button.from_icon_name("object-select-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			mark_as_played_button.has_tooltip = true;
			mark_as_played_button.relief = Gtk.ReliefStyle.NONE;
			mark_as_played_button.tooltip_text = _("Mark this episode as played");

			mark_as_new_button = new Gtk.Button.from_icon_name("non-starred-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			mark_as_new_button.has_tooltip = true;
			mark_as_new_button.relief = Gtk.ReliefStyle.NONE;
			mark_as_new_button.tooltip_text = _("Mark this episode as new");

			download_button = new Gtk.Button.from_icon_name(Utils.check_elementary() ? "browser-download-symbolic" : "document-save-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			download_button.has_tooltip = true;
			download_button.relief = Gtk.ReliefStyle.NONE;
			download_button.tooltip_text = _("Download episode");

			share_button = new Gtk.Button.from_icon_name(Utils.check_elementary() ? "send-to-symbolic" : "emblem-shared-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			share_button.has_tooltip = true;
			share_button.relief = Gtk.ReliefStyle.NONE;
			share_button.tooltip_text = _("Share this episode");
			share_button.button_press_event.connect((e) => {
                var share_menu = new Gtk.Menu();
                shareable_link = new Gtk.MenuItem.with_label(_("Copy shareable link"));
                tweet = new Gtk.MenuItem.with_label(_("Send a Tweet…"));
                link_to_file = new Gtk.MenuItem.with_label(_("Copy the direct episode link"));

                shareable_link.activate.connect(() => { copy_shareable_link(); });
           		tweet.activate.connect(() => { send_tweet(); });
            	link_to_file.activate.connect(() => { copy_direct_link(); });

                share_menu.add(shareable_link);
                share_menu.add(tweet);
                share_menu.add(new Gtk.SeparatorMenuItem());
                share_menu.add(link_to_file);
                share_menu.attach_to_widget(share_button, null);
                share_menu.show_all();
                share_menu.popup(null, null, null, e.button, e.time);
                return true;
            });

			controls_box.pack_start(mark_as_played_button, false, false, 0);
			controls_box.pack_start(mark_as_new_button, false, false, 0);
			controls_box.pack_start(download_button, false, false, 0);
			controls_box.pack_end(share_button, false, false, 0);

			title_label = new Gtk.Label("");
			title_label.get_style_context().add_class("h3");
			title_label.wrap = true;
			title_label.wrap_mode = Pango.WrapMode.WORD;
			title_label.margin_top = 20;
			title_label.margin_bottom = 6;
			title_label.margin_start = 12;
			title_label.halign = Gtk.Align.START;
			title_label.set_property("xalign", 0);

			date_label = new Gtk.Label("");
			date_label.margin_bottom = 12;
			date_label.margin_start = 12;
			date_label.halign = Gtk.Align.START;
			title_label.set_property("xalign", 0);

			play_button = new Gtk.Button.with_label("Play this episode");
			queue_button = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
			queue_button.has_tooltip = true;
			queue_button.tooltip_text = _("Add this episode to the up next list");

			var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
			button_box.pack_start(play_button, false, false, 0);
			button_box.pack_start(queue_button, false, false, 0);
			button_box.margin_bottom = 20;
			button_box.margin_start = 12;

			var summary_label = new Gtk.Label(_("<b>Summary</b>"));
			summary_label.use_markup = true;
			summary_label.margin_start = 12;
			summary_label.margin_bottom = 6;
			summary_label.halign = Gtk.Align.START;

			content_box.pack_start(controls_box, false, false, 0);
			content_box.pack_start(title_label, false, false, 0);
			content_box.pack_start(date_label, false, false, 0);
			content_box.pack_start(button_box, false, false, 0);
			content_box.pack_start(summary_label, false, false, 0);
			content_box.pack_start(shownotes_label, true, true, 0);

			this.add (content_box);
		}

		public void set_html(string html) {
			this.shownotes_label.label = html;
			shownotes_label.use_markup = true;
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

	    public void show_mark_as_new_button () {
	        mark_as_played_button.no_show_all = true;
	        mark_as_played_button.hide ();

	        mark_as_new_button.no_show_all = false;
	        mark_as_new_button.show ();
	    }

	    public void show_mark_as_played_button () {
	        mark_as_played_button.no_show_all = false;
	        mark_as_played_button.show ();

	        mark_as_new_button.no_show_all = true;
	        mark_as_new_button.hide ();
	    }
	}
}
