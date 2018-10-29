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
		public signal void refresh_selected();
		public signal void rate_button_selected();
		public signal void store_selected();
		public signal void play_pause_selected();
		public signal void seek_forward_selected();
		public signal void seek_backward_selected();
		public signal void downloads_selected();
        public signal void check_for_updates_selected();
        public signal void about_selected ();

        public Gtk.Menu             menu;
        public Gtk.MenuButton       app_menu;

		private Gtk.Button          play_pause;
        private Gtk.Button          forward;
        private Gtk.Button          backward;
        private Gtk.Button          refresh;
        public  Gtk.Button          download;
        public  Gtk.Button 			shownotes_button;
        public  Gtk.Button          volume_button;
        public  Gtk.Button          search_button;
        private Gtk.Button          podcast_store_button;
		public Gtk.Button 			playlist_button;
		public Gtk.Button new_episodes_button;

        public  Gtk.MenuItem        export_item;
        private Gtk.Box             headerbar_box;
        public  PlaybackBox         playback_box;

        private VocalSettings 		settings;

		public Toolbar(VocalSettings settings, bool? first_run = false, bool? on_elementary = Utils.check_elementary()) {

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
	     		shownotes_button = new Gtk.Button.from_icon_name("dialog-information-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            shownotes_button.tooltip_text = _("View show notes");
            shownotes_button.valign = Gtk.Align.CENTER;
            shownotes_button.clicked.connect(() => {
                shownotes_selected();
            });
            shownotes_button.relief = Gtk.ReliefStyle.NONE;
            
            volume_button = new Gtk.Button.from_icon_name("audio-volume-high-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

            playlist_button = new Gtk.Button.from_icon_name("media-playlist-consecutive-symbolic");
            playlist_button.tooltip_text = _("Coming up next");
            playlist_button.clicked.connect(() => {
                playlist_selected();
            });
            playlist_button.relief = Gtk.ReliefStyle.NONE;
            playlist_button.valign = Gtk.Align.CENTER;
            
            if(on_elementary)
                new_episodes_button = new Gtk.Button.from_icon_name ("help-about-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            else
                new_episodes_button = new Gtk.Button.from_icon_name ("starred-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            new_episodes_button.tooltip_text = _("New Episodes");
            new_episodes_button.relief = Gtk.ReliefStyle.NONE;

            headerbar_box.add(shownotes_button);
            headerbar_box.add (volume_button);
            headerbar_box.add(playback_box);
            headerbar_box.add(playlist_button);
            headerbar_box.halign = Gtk.Align.CENTER;


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

            var report_problem = new Gtk.MenuItem.with_label (_("Report a Problem…"));
            report_problem.activate.connect (() => {
                try {
                    Gtk.show_uri (null, "https://github.com/needle-and-thread/vocal/issues", 0);
                } catch (Error error) {}
            });
            menu.add(report_problem);

            var donate = new Gtk.MenuItem.with_label (_("Donate…"));
            donate.activate.connect (() => {
                try {
                    Gtk.show_uri (null, "http://needleandthread.co/apps/vocal", 0);
                } catch (Error error) {}
            });
            //menu.add(donate);

            var about = new Gtk.MenuItem.with_label (_("About"));
            about.activate.connect (() => {
                about_selected ();
            });
            menu.add (about);
            menu.show_all();

            // Create the AppMenu
            app_menu = new Gtk.MenuButton();
	     	app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", on_elementary ? on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR));
            app_menu.popup = menu;
            app_menu.relief = Gtk.ReliefStyle.NONE;
            app_menu.valign = Gtk.Align.CENTER;


            // Populate the toolbar
            pack_end (app_menu);
            set_custom_title(headerbar_box);

            // Initially hide the headearbar_box
            hide_playback_box();

            this.show_close_button = true;

            // Create new icons for placback functions and downloads
            var playpause_image = new Gtk.Image.from_icon_name("media-playback-start-symbolic", on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR);
            play_pause = new Gtk.Button();
            play_pause.image = playpause_image;
            play_pause.image = playpause_image;
            play_pause.has_tooltip = true;
            play_pause.tooltip_text = _("Play");
            play_pause.relief = Gtk.ReliefStyle.NONE;
            play_pause.valign = Gtk.Align.CENTER;

            var forward_image = new Gtk.Image.from_icon_name("media-seek-forward-symbolic", on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR);
            forward = new Gtk.Button();
            forward.image = forward_image;
            forward.has_tooltip = true;
            forward.relief = Gtk.ReliefStyle.NONE;
            forward.hexpand = true;
            forward.halign = Gtk.Align.START;
            forward.tooltip_text = _("Fast forward %d seconds".printf(this.settings.fast_forward_seconds));
            forward.valign = Gtk.Align.CENTER;

            var backward_image = new Gtk.Image.from_icon_name("media-seek-backward-symbolic", on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR);
            backward = new Gtk.Button();
            backward.image = backward_image;
            backward.has_tooltip = true;
            backward.relief = Gtk.ReliefStyle.NONE;
            backward.tooltip_text = _("Rewind %d seconds".printf(this.settings.rewind_seconds));
            backward.valign = Gtk.Align.CENTER;

			play_pause.get_style_context().add_class("vocal-headerbar-button");

            // Connect the changed signal for settings to update the tooltips
            this.settings.changed.connect(() => {
                forward.tooltip_text = _("Fast forward %d seconds".printf(this.settings.fast_forward_seconds));
                backward.tooltip_text = _("Rewind %d seconds".printf(this.settings.rewind_seconds));
            });

            refresh = new Gtk.Button.from_icon_name("view-refresh-symbolic", on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR);
            refresh.has_tooltip = true;
            refresh.tooltip_text = _("Check for new episodes");

            var rate_button = new Gtk.Button.with_label("");
			rate_button.get_style_context().add_class("rate-button");
			rate_button.get_style_context().add_class("h3");
            rate_button.relief = Gtk.ReliefStyle.NONE;
            rate_button.valign = Gtk.Align.CENTER;

            search_button = new Gtk.Button.from_icon_name("edit-find-symbolic", on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR);
            search_button.tooltip_text = _("Search your library or online");
            search_button.relief = Gtk.ReliefStyle.NONE;
            search_button.valign = Gtk.Align.CENTER;


            if(on_elementary) {
                podcast_store_button = new Gtk.Button.from_icon_name("system-software-install-symbolic", on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR);
            } else {
                podcast_store_button = new Gtk.Button.from_icon_name("application-rss+xml-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            }
            podcast_store_button.tooltip_text = _("View the top podcasts in the iTunes Store");
            podcast_store_button.relief = Gtk.ReliefStyle.NONE;
            podcast_store_button.valign = Gtk.Align.CENTER;

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
                download_image = new Gtk.Image.from_icon_name("browser-download-symbolic", on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR);
            else {
                download_image = new Gtk.Image.from_icon_name("document-save-symbolic", on_elementary ? Gtk.IconSize.LARGE_TOOLBAR : Gtk.IconSize.SMALL_TOOLBAR);
            }
            download = new Gtk.Button();
            download.image = download_image;
            download.has_tooltip = true;
            download.tooltip_text = _("Downloads");
            download.relief = Gtk.ReliefStyle.NONE;
            download.valign = Gtk.Align.CENTER;

            download.clicked.connect(() => {
            	downloads_selected();
        	});
            download.set_no_show_all(true);
            download.hide();

            // Add the buttons
            pack_start (backward);
	        pack_start (play_pause);
	        pack_start (forward);

            pack_end (search_button);
			pack_end (podcast_store_button);
	        pack_end (download);
	        pack_end (new_episodes_button);
		}


        public void hide_downloads_menuitem() {
            if(download != null) {
                download.no_show_all = true;
                download.hide();
            }
            show_all();
        }

        public void hide_playback_box() {
            if(headerbar_box != null) {
                this.headerbar_box.no_show_all = true;
                this.headerbar_box.hide();
            }
        }


        public void show_playback_box() {
            if(headerbar_box != null) {
                this.headerbar_box.no_show_all = false;
                this.headerbar_box.show();
                show_all();
            }
        }

        public void show_shownotes_button() {
            if(shownotes_button != null) {
            	shownotes_button.set_no_show_all(false);
                shownotes_button.show();
            }
        }

        public void hide_shownotes_button() {
            if(shownotes_button != null) {
            	shownotes_button.set_no_show_all(true);
                shownotes_button.hide();
            }
        }
        
        public void show_volume_button() {
            if(volume_button != null) {
            	volume_button.set_no_show_all(false);
                volume_button.show();
            }
        }

        public void hide_volume_button() {
            if(volume_button != null) {
            	volume_button.set_no_show_all(true);
                volume_button.hide();
            }
        }

		public void show_playlist_button() {
		    if(playlist_button != null) {
			    playlist_button.set_no_show_all(false);
			    playlist_button.show();
		    }
		}

		public void hide_playlist_button() {
		    if(playlist_button != null) {
			    playlist_button.set_no_show_all(true);
			    playlist_button.hide();
		    }
		}

        public void hide_download_button() {
            if(download != null) {
            	this.download.set_no_show_all(true);
                this.download.hide();
            }
        }

        public void show_download_button() {
            if(download != null) {
            	this.download.set_no_show_all(false);
                this.download.show();
            }
        }

        public void set_play_pause_image(Gtk.Image new_img) {
        	play_pause.image = new_img;
        }

        public void set_play_pause_text(string new_text) {
        	play_pause.tooltip_text = new_text;
        }
	}
}
