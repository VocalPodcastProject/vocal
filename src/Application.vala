/* Copyright 2014-2022 Nathan Dyer and Vocal Project Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Vocal {
    public class Application : Adw.Application {

        public VocalSettings settings = VocalSettings.get_default_instance ();
        public Library library = null;
        public Player player;
        public iTunesProvider itunes = null;
        public PasswordManager password_manager = PasswordManager.get_default_instance ();
        public gpodderClient gpodder_client;

        /* Signals */

        public signal void track_changed (string episode_title, string podcast_name, string artwork_uri, uint64 duration);
        public signal void playback_status_changed (string status);
        public signal void update_status_changed (bool currently_updating);
        public signal void subscriptions_changed ();

        /* Runtime flags */

        public bool first_run = true;
        public bool newly_launched = true;
        public bool should_quit_immediately = true;
        public bool plugins_are_installing = false;
        public bool checking_for_updates = false;
        public bool is_closing = false;
        public bool open_hidden = false;
        public bool currently_repopulating = false;
        public bool currently_importing = false;


        /* System */

        public GnomeMediaKeys mediakeys;
        public Gst.PbUtils.InstallPluginsContext context;

        /* References, pointers, and containers */

        public Podcast highlighted_podcast;

        /* Miscellaneous global variables */

        public int minutes_elapsed_in_period;


        public Application () {
            Object (application_id: "com.github.VocalPodcastProject.vocal", flags: ApplicationFlags.FLAGS_NONE);
        }

        construct {
            ActionEntry[] action_entries = {
                { "about", this.on_about_action },
                { "preferences", this.on_preferences_action },
                { "quit", this.quit }
            };
            this.add_action_entries (action_entries, this);
            this.set_accels_for_action ("quit", {"<primary>q"});
        }

        public override void activate () {
            base.activate ();
            var win = this.active_window;
            if (win == null) {

                // Create the Player and Initialize GStreamer
                player = Vocal.Player.get_default ();
                itunes = new iTunesProvider ();
                library = new Library (this);
                library.library_ready.connect(post_creation_sequence);
                library.run_database_update_check ();
                player.update_episode_position.connect(update_episode_position);

                gpodder_client = gpodderClient.get_default_instance (this);

                // Determine whether or not the local library exists
                first_run = (!library.check_database_exists ());

                // IMPORTANT NOTE: the player, library, and iTunes provider MUST exist before the MainWindow is created
                win = new Vocal.MainWindow (this);
                var window = win as MainWindow;

                var actions = window.list_actions();
                foreach (string action in actions) {
                    warning (action);
                }

                // Connect signals
                window.add_podcast.connect(() => {
                    var add_feed_dialog = new AddFeedDialog(win);
                    add_feed_dialog.add_podcast.connect(add_podcast_feed);
                    add_feed_dialog.show();
                });

                window.directory_view.new_subscription.connect(add_podcast_feed);
                window.search_box.new_subscription.connect(add_podcast_feed);

                // Set up the MPRIS playback functionality
                MPRIS mpris = new MPRIS (this);
                mpris.initialize ();

                // Set up media keys and keyboard shortcuts
                try {
                    mediakeys = Bus.get_proxy_sync (BusType.SESSION,
                        "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                    mediakeys.MediaPlayerKeyPressed.connect ((bus, app, key) => {
                        if (app != "vocal")
                           return;
                        switch (key) {
                            case "Previous":
                                player.skip_back (settings.rewind_seconds);
                                break;
                            case "Next":
                                player.skip_forward(settings.fast_forward_seconds);
                                break;
                            case "Play":
                                player.play_pause();
                                break;
                            default:
                                break;
                        }
                    });

                    mediakeys.GrabMediaPlayerKeys ("vocal", 0);
                } catch (Error e) { warning (e.message); }

                if (!first_run) {
                    window.populate_views.begin ((obj, res) => {
                        window.populate_views.end(res);
                    });

                } else {
                	// In case gpodder.net credentials were left over from previous install, clear them out
                	settings.gpodder_device_name = "";
                	settings.gpodder_username = "";
                	settings.gpodder_last_successful_sync_timestamp = "";

                    library.setup_library ();
                    post_creation_sequence ();
                }
            }
            settings.changed.connect(on_settings_change);
            win.present ();
        }

        private void post_creation_sequence () {
            warning ("Post creation");

            restore_state();

            // Autoclean the library if necessary
            if (settings.autoclean_library) {
                info ("Performing library autoclean.");
                library.autoclean_library.begin ((obj,res) => {
                    library.autoclean_library.end(res);
                });
            }

            // Set up the updating mechanism to trigger every 5 minutes

            // Set minutes elapsed to zero since the app is just now starting up
            minutes_elapsed_in_period = 0;

            // Automatically check for new episodes
            if (settings.update_interval != 0) {

                //Increase count and check for match every 5 minutes
                GLib.Timeout.add (300000, () => {

                    // The update interval increases/decreases by a step of 5 each time, so eventually
                    // the current count will equal the update interval. When that happens, update.
                    minutes_elapsed_in_period += 5;
                    if (minutes_elapsed_in_period == settings.update_interval) {
                        on_update_request ();
                    }

                    return true;
                });
            }

            // Automatically save state every 5 seconds
            GLib.Timeout.add (5000, () => {

                save_state ();

                return true;
            });


        	// Get new subscriptions from gpodder.net
        	//
        	/*
		    if (!library.empty () && settings.gpodder_username != "" && settings.gpodder_username.length > 1) {
		    	win.show_infobar (_("Checking for new podcast subscriptions from your other devices…"), MessageType.INFO);
		    	var loop = new MainLoop();
            	gpodder_client.get_subscriptions_list_async.begin ((obj, res) => {

		                string cloud_subs_opml = gpodder_client.get_subscriptions_list_async.end (res);
            			library.add_from_OPML (cloud_subs_opml, true, true);

		                // Next, get any episode updates
		                window.show_infobar (_("Updating episode playback positions from your other devices…"), MessageType.INFO);
		                gpodder_client.get_episode_updates_async.begin ((obj, res) => {

		                	bool? success = gpodder_client.get_episode_updates_async.end (res);

		                	// If necessary, remove podcasts from library that are missing in
		                	if (settings.gpodder_remove_deleted_podcasts) {

		                		window.show_infobar (_("Cleaning up old subscriptions no longer in your gpodder.net account…"), MessageType.INFO);

		                		// TODO: use a singleton pattern so there's only one instance
		                		FeedParser feed_parser = new FeedParser ();
		                		string[] cloud_feeds = feed_parser.parse_feeds_from_OPML (cloud_subs_opml, true);
		                		foreach (Podcast p in library.podcasts) {
		                			bool found = false;
		                			foreach (string feed in cloud_feeds) {
		                				if (p.feed_uri == feed) {
		                					found = true;
	                					}
		                			}
		                			if (!found) {
		                				// Remove podcast
		                				library.remove_podcast (p);
		                			}
		                		}
		                	}

		                	// Now update the actual feeds and quit the loop
						    on_update_request ();
				            loop.quit();
		                });

                });
                loop.run();

	    	} else {
	    	*/
            	//on_update_request ();
        	//}
        	//

        }

        private void on_about_action () {
            string[] authors = { "Nathan Dyer" };
            Gtk.show_about_dialog (this.active_window,
                                   "program-name", "vocal",
                                   "authors", authors,
                                   "version", "4.0.0");
        }

        private void on_preferences_action () {
            message ("app.preferences action activated");
        }

        /*
         * Check for new episodes
         */
        public void on_update_request () {

            // Only check for updates if no other checks are currently under way
            if (!checking_for_updates) {

                var window = this.active_window as Vocal.MainWindow;
                window.show_infobar ("Checking for updates…", Gtk.MessageType.INFO);

                checking_for_updates = true;
                update_status_changed (true);

                // Create an arraylist to store new episodes
                Gee.ArrayList<Episode> new_episodes = new Gee.ArrayList<Episode> ();

                library.check_for_updates.begin ((obj, res) => {
                    new_episodes = library.check_for_updates.end (res);
                    window.hide_infobar();
                });

                // Reset the period
                minutes_elapsed_in_period = 0;

                checking_for_updates = false;
                update_status_changed (false);

                // Send a notification if there are new episodes
                if (new_episodes.size > 0 && !settings.auto_download) {
                    if (!window.focus_visible)
                        //TODO: new notification system
                       //Utils.send_generic_notification (_ ("Fresh content has been added to your library."));

                    // Also update the number of new episodes and set the badge count
                    library.new_episode_count += new_episodes.size;
                }

                // Automatically download episodes if set to do so
                if (settings.auto_download && new_episodes.size > 0) {
                    foreach (Episode e in new_episodes) {
                        window.download_episode (e);
                    }
                }

                // Free up the memory from the arraylist
                new_episodes = null;


            } else {
                warning ("Vocal is already checking for updates.");
            }
        }

        /*
         * Does the actual adding of podcast feeds
         */
        public void add_podcast_feed (string feed) {
            if (feed.length == 0) {
                return;
            }

            currently_importing = true;

            string add_feed = feed;

            // Was the RSS feed an iTunes URL? If so, find the actual RSS feed address
            if (feed.contains ("itunes.apple.com") || feed.contains("podcasts.apple.com")) {
                add_feed = itunes.get_rss_from_itunes_url (feed);
            }

            var win = this.active_window as MainWindow;
            win.show_infobar("Adding new podcast: <b>" + add_feed + "</b>", Gtk.MessageType.INFO);

            bool success = false;

            library.async_add_podcast_from_file.begin (add_feed, (obj, res) => {
                success = library.async_add_podcast_from_file.end (res);
                currently_importing = false;

                if (success) {

                    win.populate_views.begin((obj, res) => {
                        win.populate_views.end(res);
                    });

                    /*

                	// Send update to gpodder API if necessary
                	if (settings.gpodder_username != "") {

                		info (_("Uploading subscriptions to gpodder.net."));
		            	var gpodder_loop = new MainLoop ();
		            	window.show_infobar (_("Uploading subscriptions to gpodder.net…"), MessageType.INFO);
		                gpodder_client.upload_subscriptions_async.begin ((obj, res) => {
	                        gpodder_client.upload_subscriptions_async.end (res);
	                        window.hide_infobar ();
		                    gpodder_loop.quit ();
		                });
		                gpodder_loop.run ();
	                }

	                */

                    win.hide_infobar();

                    // Is there now at least one podcast in the library?
                    if (library.podcasts.size > 0) {

                    }
                } else {

                    // Determine if it was a network issue, or just a problem with the feed
                    bool network_okay = SoupClient.check_connection ();

                    string error_message;

                    if (network_okay) {
                        error_message = _ ("Please make sure you selected the correct feed and that it is still available.");
                    } else {
                        error_message = _ ("There seems to be a problem with your internet connection. Make sure you are online and then try again.");
                    }

                    win.show_infobar(error_message, Gtk.MessageType.ERROR);

                }
            });
        }

        private void on_settings_change(string key) {
            if (key == "show-name-label") {
                var win = active_window as MainWindow;
                if(settings.show_name_label) {
                    win.show_name_labels();
                } else {
                    win.hide_name_labels();
                }
            } else if (key == "theme-preference") {

                var style_manager = Adw.StyleManager.get_default();

                if (settings.theme_preference == "system") {
                    style_manager.color_scheme = Adw.ColorScheme.DEFAULT;
                } else if (settings.theme_preference == "dark") {
                    style_manager.color_scheme = Adw.ColorScheme.PREFER_DARK;
                } else {
                    style_manager.color_scheme = Adw.ColorScheme.PREFER_LIGHT;
                }
            }
        }

        private void update_episode_position (Episode e, uint64 position) {
            e.last_played_position = position;
            library.set_episode_playback_position(e);
        }

        private void restore_state() {

            var win = active_window as MainWindow;

            // Restore playing episode
            if (settings.last_played_media != null && settings.last_played_media.length > 1) {

                // Split the media into two different strings
                string[] fields = settings.last_played_media.split (",");
                bool found = false;
                foreach (Podcast podcast in library.podcasts) {
                    if (!found) {
                        if (podcast.name == fields[0]) {
                            found = true;

                            // Attempt to find the matching episode, set it as the current episode, and display the information in the box
                            foreach (Episode episode in podcast.episodes) {
                                if (episode.title == fields[01]) {
                                    win.playbackbox.set_info_title(episode.title, episode.parent.name);
                                    win.playbackbox.set_description(episode.description);
                                    player.set_episode (episode);

                                }
                            }
                        }
                    }
                }
            }


            if (settings.last_queue_contents != null && settings.last_queue_contents.length > 1) {
                // Items are separated by semicolons
                string[] items = settings.last_queue_contents.split (";");
                foreach (string item in items) {

                    // Get podcast and episode names
                    string[] fields = item.split (",");
                    bool found = false;
                    foreach (Podcast podcast in library.podcasts) {
                        if (!found) {
                            if (podcast.name == fields[0]) {
                                found = true;
                                // Attempt to find the matching episode, set it as the current episode, and display the information in the box
                                foreach (Episode episode in podcast.episodes) {
                                    if (episode.title == fields[1]) {
                                        library.enqueue_episode (episode);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        private void save_state () {

            // Save window geometry
            settings.window_width = active_window.get_width();
            settings.window_height = active_window.get_height();

            // Write episode changes to db
            if(player.current_episode != null && player.get_position() > 0) {
                player.current_episode.last_played_position = player.get_position();
                library.set_episode_playback_position(player.current_episode);

                // Save current episode and queue
                settings.last_played_media = player.current_episode.parent.name + "," + player.current_episode.title;
                string queue_contents = "";
                foreach(Episode e in library.queue) {
                    queue_contents += e.parent.name + "," + e.title + ";";
                }
                settings.last_queue_contents = queue_contents;
            }
        }
    }
}
