/***
  BEGIN LICENSE

  Copyright (C) 2014-2018 Nathan Dyer <mail@nathandyer.me>
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

using Clutter;
using Gtk;
using Gdk;
using Granite;
using Granite.Services;
using Granite.Widgets;

namespace Vocal {

    public class Controller : GLib.Object {

        public MainWindow window = null;
        public VocalApp app = null;
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

        /* Runtime flags */

        public bool first_run = true;
        public bool newly_launched = true;
        public bool should_quit_immediately = false;
        public bool plugins_are_installing = false;
        public bool checking_for_updates = false;
        public bool is_closing = false;
        public bool on_elementary = Utils.check_elementary ();
        public bool open_hidden = false;
        public bool currently_repopulating = false;
        public bool currently_importing = false;

        /* System */

        public GnomeMediaKeys mediakeys;
        public Gst.PbUtils.InstallPluginsContext context;

        /* References, pointers, and containers */

        private Episode current_episode;
        public Podcast highlighted_podcast;

        /* Miscellaneous global variables */

        public int minutes_elapsed_in_period;

        public Controller (VocalApp app) {

            info ("Initializing the controller.");

            this.app = app;

            info ("Initializing the player from GStreamer.");

            // Create the Player and Initialize GStreamer
            player = Player.get_default (app.args);

            info ("Initializing the iTunes store provider.");

            itunes = new iTunesProvider ();

            info ("Establishing a connection to your podcast library.");

            library = new Library (this);
            library.run_database_update_check ();
            
            info ("Initiating the gpodder API");
            gpodder_client = gpodderClient.get_default_instance (this);

            // Determine whether or not the local library exists
            first_run = (!library.check_database_exists ());

            // Use Dark theme by default if option is set globally
            if (first_run && Gtk.Settings.get_default ().gtk_application_prefer_dark_theme) {
                settings.dark_mode_enabled = true;
            }
            
            // IMPORTANT NOTE: the player, library, and iTunes provider MUST exist before the MainWindow is created

            info ("Initializing the main window.");

            window = new MainWindow (this);

            // Once the Window exists, connect player signals
            player.eos.connect (window.on_stream_ended);
            player.additional_plugins_required.connect (window.on_additional_plugins_needed);


            info ("Initializing MPRIS playback.");

            // Set up the MPRIS playback functionality
            MPRIS mpris = new MPRIS (this);
            mpris.initialize ();

            // Restore last played Episode after MPRIS has been initialized
            mpris.initialized.connect (restore_episode);


            // Connect the new player position available signal from the player
            // to set the new progress on the playback box
            player.new_position_available.connect (() => {

                if (player.progress > 0) {
                    player.current_episode.last_played_position = (int) player.get_position ();
                }

                int mins_remaining;
                int secs_remaining;
                int mins_elapsed;
                int secs_elapsed;

                // Progress is a percentage of completiong. Multiple by duration to get elapsed.
                double total_secs_elapsed = player.duration * player.progress;

                mins_elapsed = (int) total_secs_elapsed / 60;
                secs_elapsed = (int) total_secs_elapsed % 60;

                double total_secs_remaining = player.duration - total_secs_elapsed;

                mins_remaining = (int) total_secs_remaining / 60;
                secs_remaining = (int) total_secs_remaining % 60;

                if (!currently_importing && player.progress != 0) {
                    window.toolbar.playback_box.set_progress (player.progress, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);
                    window.video_controls.set_progress (player.progress, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);
                }
            });

            info ("Initializing notifications.");

            //TODO: Replace libnotify with GLib.Notification
            // Initialize notifications (if libnotify is present and enabled)
#if HAVE_LIBNOTIFY
            Notify.init ("Vocal");
#endif

            info ("Setting up media keys.");

            // Set up media keys and keyboard shortcuts
            try {
                mediakeys = Bus.get_proxy_sync (BusType.SESSION,
                    "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                mediakeys.MediaPlayerKeyPressed.connect ((bus, app, key) => {
                    if (app != "vocal")
                       return;
                    switch (key) {
                        case "Previous":
                            seek_backward ();
                            break;
                        case "Next":
                            seek_forward ();
                            break;
                        case "Play":
                            play_pause ();
                            break;
                        default:
                            break;
                    }
                });

                mediakeys.GrabMediaPlayerKeys ("vocal", 0);
            } catch (Error e) { warning (e.message); }


            info ("Setting up keyboard shortcuts.");


            // Set up all the keyboard shortcuts
            window.key_press_event.connect ((e) => {

                bool handled = false;

                // Was the control key pressed?
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    switch (e.keyval) {
                        case Gdk.Key.q:
                            window.destroy ();
                            handled = true;
                            break;
                        case Gdk.Key.f:
                            window.on_show_search ();
                            handled = true;
                            break;
                        default:
                            break;
                    }
                } else {
                    switch (e.keyval) {
                        case Gdk.Key.space:
                            if (!window.search_results_view.search_entry.has_focus) {
                                play_pause ();
                                handled = true;
                            }

                            break;
                        case Gdk.Key.F11:
                            window.on_fullscreen_request ();
                            handled = true;
                            break;
                        case Gdk.Key.Escape:
                            if (window.fullscreened) {
                                window.on_fullscreen_request ();
                                handled = true;
                            }

                            break;

                        case Gdk.Key.Left:
                            if (!window.search_results_view.search_entry.has_focus) {
                                seek_backward ();
                                handled = true;
                            }
                            break;
                        case Gdk.Key.Right:
                            if (!window.search_results_view.search_entry.has_focus) {
                                seek_forward ();
                                handled = true;
                            }
                            break;
                        }
                }

                return handled;
            });

            // Connect the library's signals
            library.import_status_changed.connect (window.on_import_status_changed);
            library.download_finished.connect (window.on_download_finished);

            if (!first_run) {
                info ("Refilling library.");
                library.refill_library ();
            } else {
            	// In case gpodder.net credentials were left over from previous install, clear them out
            	settings.gpodder_device_name = "";
            	settings.gpodder_username = "";
            	settings.gpodder_last_successful_sync_timestamp = "";

                info ("Setting up library.");
                library.setup_library ();
            }

            if (first_run || library.empty ()) {
                window.toolbar.new_episodes_button.set_no_show_all (true);
                window.toolbar.new_episodes_button.hide ();
            }

            // Autoclean the library if necessary
            if (settings.autoclean_library) {
                info ("Performing library autoclean.");
                library.autoclean_library ();
            }
   
            info ("Controller initialization finished. Running post-creation sequence.");
            post_creation_sequence ();
        }

        private void post_creation_sequence () {

            // Show the welcome widget if it's the first run, or if the library is empty
            if (first_run || library.empty ()) {
                window.show_all ();
                window.switch_visible_page (window.welcome);
                if (library.pending_import != null) {
                    info ("Starting subscription migration as import: %s", library.pending_import);
                    window.import_podcasts (library.pending_import);
                }
            } else {
                // Populate the IconViews from the library
                window.populate_views ();
                window.show_all ();
                window.switch_visible_page (window.all_scrolled);
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
            

        	// Get new subscriptions from gpodder.net
		    if (!library.empty () && settings.gpodder_username != "") {
		    	window.show_infobar (_("Checking for new podcast subscriptions from your other devices…"), MessageType.INFO);
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
            	on_update_request ();
        	}
        }

        public void set_episode (Episode? e) {
            if (current_episode != null) {
                library.set_episode_playback_position (current_episode);
            }

            current_episode = e;
            if (current_episode != null) {
                try {
                    player.set_episode (current_episode);
                    window.toolbar.playback_box.set_info_title (current_episode.title.replace ("%27", "'"), current_episode.parent.name.replace ("%27", "'"));
                    window.toolbar.playback_box.set_artwork_image_image (current_episode.parent.coverart_uri);
                    track_changed (current_episode.title, current_episode.parent.name, current_episode.parent.coverart_uri, (uint64) player.duration);
                    settings.last_played_media = {current_episode.guid, current_episode.link, current_episode.podcast_uri};
                    window.artwork_popover.set_notes_text (current_episode.description);
                } catch (Error e) {
                    warning (e.message);
                }

                window.toolbar.show_playback_box ();
            } else {
                window.toolbar.hide_playback_box ();
            }
        }

        public Episode get_episode () {
            return current_episode;
        }

        private void restore_episode () {
            if (settings.last_played_media != null && settings.last_played_media.length > 2) {

                info ("Restoring last played media.");

                // Split the media into two different strings
                string[] fields = settings.last_played_media;
                bool found = false;
                foreach (Podcast podcast in library.podcasts) {

                    if (!found) {
                        if (podcast.feed_uri == fields[2]) {
                            found = true;

                            // Attempt to find the matching episode, set it as the current episode, and display the information in the box
                            foreach (Episode episode in podcast.episodes) {
                                if (episode.guid == fields[0] && episode.link == fields[1]) {
                                    set_episode (episode);
                                }
                            }
                        }
                    }
                }
            }
        }

        /*
         * Playback related methods
         */

        /*
         * Determines whether the play button should play or pause, and calls
         * the appropriate function
         */

        public void play_pause () {

            // If the player is playing, pause. Otherwise, play
            if (player != null) {
                if (player.playing) {
                    pause ();
                } else {
                    play ();
                }
            }
        }


        /*
         * Handles play requests and starts media playback using the player
         */
        public void play () {

            if (current_episode != null) {
                window.toolbar.show_playback_box ();

                //If the current episode is unplayed, subtract one from unplayed total and display
                if (current_episode.status == EpisodeStatus.UNPLAYED) {
                    window.current_episode_art.set_count (window.details.unplayed_count);
                    if (window.details.unplayed_count > 0)
                        window.current_episode_art.show_count ();
                    else
                        window.current_episode_art.hide_count ();
                    library.new_episode_count--;
                    library.set_new_badge ();
                }

                // Mark the current episode as played
                library.mark_episode_as_played (current_episode);

                // If the currently selected episode isn't set, do so
                if (player.current_episode != current_episode) {

                    // Save the position information from the previous episode
                    if (player.current_episode != null) {
                        library.set_episode_playback_position (player.current_episode);
                    }

                    player.set_episode (current_episode);
                }


                // Are we playing a video? If so, is the video widget already being displayed?
                if (player.current_episode.parent.content_type == MediaType.VIDEO && window.current_widget != window.video_widget) {

                    // If you want to see a pretty animation, you must give the player time to configure everything
                    GLib.Timeout.add (1000, () => {
                        window.switch_visible_page (window.video_widget);
                        return false;
                    });
                }

                player.play ();
                playback_status_changed ("Playing");

                var playpause_image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                window.toolbar.set_play_pause_image (playpause_image);
                window.toolbar.set_play_pause_text (_ ("Pause"));

                var video_playpause_image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                window.video_controls.play_button.image = video_playpause_image;
                window.video_controls.tooltip_text = _ ("Pause");


                // Set the media information (assuming we're not importing. If we are, the import status is more important
                // and the media info will be correctly set after it is finished.)
                if (!currently_importing) {
                    window.toolbar.playback_box.set_info_title (current_episode.title.replace ("%27", "'"), current_episode.parent.name.replace ("%27", "'"));
                    window.video_controls.set_info_title (current_episode.title.replace ("%27", "'"), current_episode.parent.name.replace ("%27", "'"));
                    window.artwork_popover.set_notes_text (current_episode.description);
                }
                window.show_all();
                
                gpodder_client.update_episode (current_episode, EpisodeAction.PLAY);

            }
        }

        /* Pauses playback if it is currently playing */
        public void pause () {

            // If we are playing, switch to paused mode.
            if (player.playing) {
                player.pause ();
                playback_status_changed ("Paused");
                var playpause_image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                window.toolbar.set_play_pause_image (playpause_image);
                window.toolbar.set_play_pause_text (_ ("Play"));

                var video_playpause_image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                window.video_controls.play_button.image = video_playpause_image;
                window.video_controls.tooltip_text = _ ("Play");

                // Set last played position
                current_episode.last_played_position = (int) player.get_position ();
                library.set_episode_playback_position (player.current_episode);
            }

            // Set the media information (assuming we're not importing. If we are, the import status is more important
            // and the media info will be correctly set after it is finished.)
            if (!currently_importing) {
                window.toolbar.playback_box.set_info_title (current_episode.title.replace ("%27", "'"), current_episode.parent.name.replace ("%27", "'"));
                window.video_controls.set_info_title (current_episode.title.replace ("%27", "'"), current_episode.parent.name.replace ("%27", "'"));
                window.artwork_popover.set_notes_text (current_episode.description);
            }

            window.show_all();
            
            gpodder_client.update_episode (current_episode, EpisodeAction.PLAY);
        }

        /*
         * Seeks backward using the player by the number of settings specified in settings
         */
        public void seek_backward () {
            player.seek_backward (settings.rewind_seconds);
        }

        /*
         * Seeks forward using the player by the number of settings specified in settings
         */
        public void seek_forward () {
            player.seek_forward (settings.fast_forward_seconds);
        }


        /*
         * Does the actual adding of podcast feeds
         */
        public void add_podcast_feed (string feed) {
            if (feed.length == 0) {
                return;
            }
            // Destroy the add podcast dialog box
            //  window.add_feed.destroy ();

            info ("Adding feed %s", feed);
            currently_importing = true;

            // Was the RSS feed an iTunes URL? If so, find the actual RSS feed address
            if (feed.contains ("itunes.apple.com")) {
                string actual_rss = itunes.get_rss_from_itunes_url (feed);
                if (actual_rss != null) {
                    info ("Original iTunes URL: %s, Vocal found matching RSS address: %s", feed, actual_rss);
                    feed = actual_rss;
                } else {
                    return;
                }
            }

            window.show_infobar (_ ("Adding new podcast: <b>" + feed + "</b>"), MessageType.INFO);

            var loop = new MainLoop ();
            bool success = false;

            library.async_add_podcast_from_file (feed, (obj, res) => {
                success = library.async_add_podcast_from_file.end (res);
                currently_importing = false;
                if (player.playing) {
                    window.toolbar.playback_box.set_info_title (current_episode.title.replace ("%27", "'"), current_episode.parent.name.replace ("%27", "'"));
                    window.video_controls.set_info_title (current_episode.title.replace ("%27", "'"), current_episode.parent.name.replace ("%27", "'"));
                }
                loop.quit ();
            });

            loop.run ();
            window.hide_infobar ();

            if (success) {

                window.hide_infobar ();
                window.toolbar.playback_box.show_artwork_image ();
                window.toolbar.playback_box.show_volume_button ();
            
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
            	
                if (!player.playing)
                    window.toolbar.hide_playback_box ();

                // Is there now at least one podcast in the library?
                if (library.podcasts.size > 0) {
                    // Make the refresh and export items sensitive now
                    //refresh_item.sensitive = true;
                    window.toolbar.export_item.sensitive = true;

                    // Populate views no matter what
                    window.populate_views_async ();

                    if (window.current_widget == window.welcome) {
                        window.switch_visible_page (window.all_scrolled);
                    }

                    window.show_all ();
                }
            } else {
                if (!player.playing) {
                    window.toolbar.hide_playback_box ();
                }

                var add_err_dialog = new Gtk.MessageDialog (window.add_feed,
                Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK, "");
                add_err_dialog.response.connect ((response_id) => {
                    add_err_dialog.destroy ();
                });

                // Determine if it was a network issue, or just a problem with the feed
                bool network_okay = SoupClient.check_connection ();

                string error_message;

                if (network_okay) {
                    error_message = _ ("Please make sure you selected the correct feed and that it is still available.");
                } else {
                    error_message = _ ("There seems to be a problem with your internet connection. Make sure you are online and then try again.");
                }

                var error_img = new Gtk.Image.from_icon_name ("dialog-error", Gtk.IconSize.DIALOG);
                add_err_dialog.set_transient_for (window);
                add_err_dialog.text = _ ("Error Adding Podcast");
                add_err_dialog.secondary_text = error_message;
                add_err_dialog.set_image (error_img);
                add_err_dialog.show_all ();
            }
        }

        /*
         * Check for new episodes
         */
        public void on_update_request () {

            // Only check for updates if no other checks are currently under way
            if (!checking_for_updates) {

                info ("Checking for updates.");
                
                window.show_infobar ("Checking for updates…", MessageType.INFO);

                checking_for_updates = true;
                update_status_changed (true);

                // Create an arraylist to store new episodes
                Gee.ArrayList<Episode> new_episodes = new Gee.ArrayList<Episode> ();

                var loop = new MainLoop ();
                library.check_for_updates.begin ((obj, res) => {
                    try {
                        new_episodes = library.check_for_updates.end (res);
                    } catch (Error e) {
                        warning (e.message);
                    }
                    loop.quit ();
                });
                loop.run ();

                // Reset the period
                minutes_elapsed_in_period = 0;

                checking_for_updates = false;
                update_status_changed (false);

                // Send a notification if there are new episodes
                if (new_episodes.size > 0 && !settings.auto_download) {
                    if (!window.focus_visible)
                       Utils.send_generic_notification (_ ("Fresh content has been added to your library."));

                    // Also update the number of new episodes and set the badge count
                    library.new_episode_count += new_episodes.size;
                    library.set_new_badge ();
                }

                // Automatically download episodes if set to do so
                if (settings.auto_download && new_episodes.size > 0) {
                    foreach (Episode e in new_episodes) {
                        window.download_episode (e);
                    }
                }

                int new_episode_count = new_episodes.size;
                
                window.hide_infobar ();

                // Free up the memory from the arraylist
                new_episodes = null;

                // Lastly, if there are new episodes, repopulate the views to obtain new counts
                if (new_episode_count > 0) {
                    info ("Repopulating views after the update process has finished.");
                    window.populate_views_async ();
                }
                
                
            } else {
                info ("Vocal is already checking for updates.");
            }
        }
    }
}
