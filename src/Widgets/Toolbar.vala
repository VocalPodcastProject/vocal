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
	public class Toolbar : Gtk.HeaderBar {

		public signal void add_podcast_selected();
		public signal void import_podcasts_selected();
		public signal void export_selected();
		public signal void shownotes_selected();
		public signal void playlist_selected();
		public signal void preferences_selected();
		public signal void donate_selected();
		public signal void search_changed();
		public signal void refresh_selected();
		public signal void rate_button_selected();
		public signal void store_selected();
		public signal void play_pause_selected();
		public signal void seek_forward_selected();
		public signal void seek_backward_selected();
		public signal void downloads_selected();
		public signal void starterpack_selected();
        public signal void check_for_updates_selected();

		public bool search_visible = false;

        private Gtk.Menu            menu;
        public Gtk.MenuButton       app_menu;

		private Gtk.Button          play_pause;
        private Gtk.Button          forward;
        private Gtk.Button          backward;
        private Gtk.Button          refresh;
        public  Gtk.Button          download;
        public  Gtk.Button 			shownotes_button;
        private Gtk.Button          podcast_store_button;
		public Gtk.Button 			playlist_button;

        public  Gtk.MenuItem        export_item;
        public  Gtk.SearchEntry     search_entry;
        private Gtk.Box             headerbar_box;
        public  PlaybackBox         playback_box;

        private VocalSettings 		settings;

		public Toolbar(VocalSettings settings, bool? first_run = false, bool? on_elementary = true) {

			this.settings = settings;

			// Create the box that will be used for the title in the headerbar
            headerbar_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);

            // Create the box to be shown during playback
            playback_box = new PlaybackBox();

            // Set the playback box in the middle of the HeaderBar
	        playback_box.hexpand = true;

            // Create the show notes button
		    if(on_elementary)
	            shownotes_button = new Gtk.Button.from_icon_name("help-info-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
		    else
	     		shownotes_button = new Gtk.Button.from_icon_name("text-x-generic", Gtk.IconSize.SMALL_TOOLBAR);
            shownotes_button.tooltip_text = _("View show notes");
            shownotes_button.clicked.connect(() => {
                shownotes_selected();
            });


            playlist_button = new Gtk.Button.from_icon_name("media-playlist-consecutive-symbolic");
            playlist_button.tooltip_text = _("Coming up next");
            playlist_button.clicked.connect(() => {
                playlist_selected();
            });

            headerbar_box.add(shownotes_button);
            headerbar_box.add(playback_box);
            headerbar_box.add(playlist_button);


            // Create the menus and menuitems
            menu = new Gtk.Menu ();

            var check_for_updates = new Gtk.MenuItem.with_label(_("Check for Updates"));
            check_for_updates.activate.connect(() => {
                check_for_updates_selected();
            });

            var add_feed_item = new Gtk.MenuItem.with_label(_("Add Podcast Feed…"));
            add_feed_item.activate.connect(() => {
                add_podcast_selected();
            });

            var import_item = new Gtk.MenuItem.with_label(_("Import Subcriptions…"));
            import_item.activate.connect(() => {
                import_podcasts_selected();
            });

            export_item = new Gtk.MenuItem.with_label(_("Export Subscriptions…"));

            // Set refresh and export insensitive if there isn't a library to export
            if(first_run) {
                //refresh_item.sensitive = false;
                export_item.sensitive = false;
            }
            export_item.activate.connect(() => {
            	export_selected();
        	});
            menu.add(check_for_updates);
            menu.add(new Gtk.SeparatorMenuItem());
            menu.add(add_feed_item);
            menu.add(import_item);
            menu.add(export_item);
            menu.add(new Gtk.SeparatorMenuItem());


            var preferences_item = new Gtk.MenuItem.with_label(_("Preferences"));
            preferences_item.activate.connect(() => {
                preferences_selected();
            });
            menu.add(preferences_item);
            menu.add(new Gtk.SeparatorMenuItem());

            var starterpack = new Gtk.MenuItem.with_label (_("Check Out The Vocal Starter Pack…"));
            starterpack.activate.connect (() => {
                starterpack_selected();
            });
            menu.add(starterpack);

            var report_problem = new Gtk.MenuItem.with_label (_("Report a Problem…"));
            report_problem.activate.connect (() => {
                try {
                    GLib.Process.spawn_command_line_async ("xdg-open https://github.com/vocalapp/vocal/issues");
                } catch (Error error) {}
            });
            menu.add(report_problem);

            var donate = new Gtk.MenuItem.with_label (_("Donate…"));
            donate.activate.connect (() => {
                try {
                    GLib.Process.spawn_command_line_async ("xdg-open http://vocalproject.net/donate");
                } catch (Error error) {}
            });
            menu.add(donate);
            menu.show_all();

            // Create the AppMenu
            app_menu = new Gtk.MenuButton();
	     	app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
            app_menu.popup = menu;


            // Populate the toolbar
            pack_end (app_menu);
            set_custom_title(headerbar_box);

            // Initially hide the headearbar_box
            hide_playback_box();

            this.show_close_button = true;

            // Create new icons for placback functions and downloads
            var playpause_image = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            play_pause = new Gtk.Button();
            play_pause.image = playpause_image;
            play_pause.image = playpause_image;
            play_pause.has_tooltip = true;
            play_pause.tooltip_text = _("Play");

            var forward_image = new Gtk.Image.from_icon_name("media-seek-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            forward = new Gtk.Button();
            forward.image = forward_image;
            forward.has_tooltip = true;
            forward.tooltip_text = _("Fast forward %d seconds".printf(this.settings.fast_forward_seconds));

            var backward_image = new Gtk.Image.from_icon_name("media-seek-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            backward = new Gtk.Button();
            backward.image = backward_image;
            backward.has_tooltip = true;
            backward.tooltip_text = _("Rewind %d seconds".printf(this.settings.rewind_seconds));

			play_pause.get_style_context().add_class("vocal-headerbar-button");

            // Connect the changed signal for settings to update the tooltips
            this.settings.changed.connect(() => {
                forward.tooltip_text = _("Fast forward %d seconds".printf(this.settings.fast_forward_seconds));
                backward.tooltip_text = _("Rewind %d seconds".printf(this.settings.rewind_seconds));
            });

            refresh = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            refresh.has_tooltip = true;
            refresh.tooltip_text = _("Check for new episodes");

            var rate_button = new Gtk.Button.with_label("");
			rate_button.get_style_context().add_class("rate-button");
			rate_button.get_style_context().add_class("h3");
            rate_button.relief = Gtk.ReliefStyle.NONE;

            search_entry = new Gtk.SearchEntry();
            search_entry.editable = true;
            search_entry.placeholder_text = _("Search your library or online");
            search_entry.visibility = true;
            search_entry.expand = true;
            search_entry.max_width_chars = 30;
            search_entry.margin_right = 12;

            search_entry.search_changed.connect(() => {
                search_changed();
            });

            podcast_store_button = new Gtk.Button.from_icon_name("applications-internet-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            podcast_store_button.tooltip_text = _("View the top podcasts in the iTunes Store");

            // Connect signals to appropriate handlers
            refresh.clicked.connect(() => {
        		refresh_selected();
            });

            play_pause.clicked.connect(() => {
            	play_pause_selected();
            });
            forward.clicked.connect(() => {
            	seek_forward_selected();
        	});
            backward.clicked.connect(() => {
            	seek_backward_selected();
            });
            rate_button.clicked.connect(() => {
                rate_button_selected();
            });
            podcast_store_button.clicked.connect(() => {
                store_selected();
            });


            Gtk.Image download_image;
            if(on_elementary)
                download_image = new Gtk.Image.from_icon_name("browser-download-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            else {
                download_image = new Gtk.Image.from_icon_name("document-save-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            }
            download = new Gtk.Button();
            download.image = download_image;
            download.has_tooltip = true;
            download.tooltip_text = _("Downloads");

            download.clicked.connect(() => {
            	downloads_selected();
        	});
            download.set_no_show_all(true);
            download.hide();

            // Add the buttons
            pack_start (backward);
	        pack_start (play_pause);
	        pack_start (forward);

			pack_end (podcast_store_button);
	        pack_end (download);
            pack_end (search_entry);
	        //pack_start(rate_button);
		}


        public void hide_downloads_menuitem() {
            download.no_show_all = true;
            download.hide();
            show_all();
        }

        public void hide_playback_box() {

            this.headerbar_box.no_show_all = true;
            this.headerbar_box.hide();
        }


        public void show_playback_box() {
            this.headerbar_box.no_show_all = false;
            this.headerbar_box.show();
            show_all();
        }

        public void show_shownotes_button() {
        	shownotes_button.set_no_show_all(false);
            shownotes_button.show();
        }

        public void hide_shownotes_button() {
        	shownotes_button.set_no_show_all(true);
            shownotes_button.hide();
        }

		public void show_playlist_button() {
			playlist_button.set_no_show_all(false);
			playlist_button.show();
		}

		public void hide_playlist_button() {
			playlist_button.set_no_show_all(true);
			playlist_button.hide();
		}

        public void hide_download_button() {
        	this.download.set_no_show_all(true);
            this.download.hide();
        }

        public void show_download_button() {
        	this.download.set_no_show_all(false);
            this.download.show();
        }

        public void set_play_pause_image(Gtk.Image new_img) {
        	play_pause.image = new_img;
        }

        public void set_play_pause_text(string new_text) {
        	play_pause.tooltip_text = new_text;
        }
	}
}
