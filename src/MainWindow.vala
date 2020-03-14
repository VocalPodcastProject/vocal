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

    public class MainWindow : Gtk.Window {

        /* Core components */

        private Controller controller;

        /* Primary widgets */

        public Toolbar toolbar;
        private Gtk.Box box;
        public Welcome welcome;
        private DirectoryView directory;
        public SearchResultsView search_results_view;
        public NewEpisodesView new_episodes_view;
        private Gtk.Stack notebook;
        public PodcastView details;
        private Gtk.Box import_message_box;

        /* Secondary widgets */

        public AddFeedDialog add_feed;
        private DownloadsPopover downloads;
        public ArtworkPopover artwork_popover;
        private Gtk.MessageDialog missing_dialog;
        private SettingsDialog settings_dialog;
        public VideoControls video_controls;
        private Gtk.Revealer return_revealer;
        private Gtk.Button return_to_library;
        private Gtk.Box search_results_box;
        private SyncDialog sync_dialog;
        private Gtk.InfoBar infobar;

        /* Icon views and related variables */

        public Gtk.FlowBox all_flowbox;
        public Gtk.ScrolledWindow all_scrolled;
        public Gtk.ScrolledWindow directory_scrolled;
        public Gtk.ScrolledWindow search_results_scrolled;

        /* Video playback */

        public Clutter.Actor actor;
        public GtkClutter.Actor bottom_actor;
        public GtkClutter.Actor return_actor;
        public Clutter.Stage stage;
        public GtkClutter.Embed video_widget;

        /* Miscellaneous Global Variables */
        public CoverArt current_episode_art;
        public Gtk.Widget current_widget;
        public Gtk.Widget previous_widget;
        public Gee.ArrayList<CoverArt> all_art;
        private bool ignore_window_state_change = false;
        private uint hiding_timer = 0; // Used for hiding video controls
        private bool mouse_primary_down = false;
        public bool fullscreened = false;
        private Gtk.Box parent_box = null;

        /*
         * Constructor for the main window. Creates the window and gets everything going.
         */
        public MainWindow (Controller controller) {

            this.controller = controller;
            title = _ ("Vocal");

            const string HEADERBAR_STYLESHEET = "@define-color colorPrimary #af81d6;";

            const string PRIMARY_STYLESHEET = """

                .album-artwork {
                    border-color: shade (mix (rgb (255, 255, 255), #fff, 0.5), 0.9);
                    border-style: solid;
                    border-width: 3px;

                    background-color: #8e8e93;
                }

                .controls {
                    background-color: #FFF;
                }
                
                .play-button {
                	border-radius: 0px;
                }
                
                .forward-button {
                	border-top-left-radius: 0px;
                	border-bottom-left-radius: 0px;
                }
                
                .backward-button {
                	border-top-right-radius: 0px;
                	border-bottom-right-radius: 0px;
            	}


                .episode-list {
                    border-bottom: 0.5px solid #8a9580;
                }

                .coverart, .directory-art {
                    background-color: #FFF;
                    border-color: shade (mix (rgb (255, 255, 255), #fff, 0.5), 0.9);
                    box-shadow: 3px 3px 3px #777;
                    border-style: solid;
                    border-width: 0.4px;

                    color: #000;
                }

                .coverart-overlay {
                    font-size: 1.7em;
                    font-family: sans;
                    color: white;
                    background-color: #af81d6;
                    border-radius: 100%;
                    padding: 12px;
                }

                .directory-art-image {
                    border-bottom: 1px solid #EFEFEF;
                }

                .directory-flowbox {
                    background-color: #E8E8E8;
                }

                .download-detail-box {
                    border-bottom: 0.5px solid #8a9580;
                }

                .h2 {
                    font-size: 1.5em;
                }

                .h3 {
                    font-size: 1.3em;
                }

                .library-toolbar {
                    background-image: -gtk-gradient (linear,
                                         left top, left bottom,
                                         from (shade (@bg_color, 0.9)),
                                         to (@bg_color));
                    border-bottom: 0.3px solid black;
                }

                .podcast-view-coverart {
                    box-shadow: 5px 5px 5px #777;
                    border-style: none;
                }

                .podcast-view-toolbar {
                }


                .rate-button {
                    color: shade (#000, 1.60);
                }


                .sidepane-toolbar {
                    background-color: #fff;
                }

                .video-widgets-background {
                    background-color: #af81d6;
                }

                """;

            info ("Loading CSS providers.");
            var css_provider = new Gtk.CssProvider ();
            css_provider.load_from_buffer (PRIMARY_STYLESHEET.data);

            var headerbar_css_provider = new Gtk.CssProvider ();
            headerbar_css_provider.load_from_buffer (HEADERBAR_STYLESHEET.data);

            var screen = Gdk.Screen.get_default ();
            var style_context = this.get_style_context ();

            // No matter what, make sure primary CSS provider is added
            style_context.add_provider_for_screen (screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            this.set_application (controller.app);

            if (controller.settings.dark_mode_enabled) {
                Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", true);
            } else {
                style_context.add_provider_for_screen (screen, headerbar_css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }

            // Set window properties
            this.set_default_size (controller.settings.window_width, controller.settings.window_height);
            this.window_position = Gtk.WindowPosition.CENTER;

            // Set up the close event
            this.delete_event.connect (on_window_closing);
            this.window_state_event.connect ((e) => {
                if (!ignore_window_state_change) {
                    on_window_state_changed (e.window.get_state ());
                } else {
                    unmaximize ();
                }
                ignore_window_state_change = false;
                return false;
            });



            info ("Creating video playback widgets.");

            // Create the drawing area for the video widget
            video_widget = new GtkClutter.Embed ();
            video_widget.use_layout_size = false;
            video_widget.button_press_event.connect (on_video_button_press_event);
            video_widget.button_release_event.connect (on_video_button_release_event);

            stage = (Clutter.Stage) video_widget.get_stage ();
            stage.background_color = {0, 0, 0, 0};
            stage.use_alpha = true;

            actor = new Clutter.Actor ();
            var aspect_ratio = new ClutterGst.Aspectratio ();
            ((ClutterGst.Content) aspect_ratio).player = controller.player;
            actor.content = aspect_ratio;

            actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));
            stage.add_child (actor);

            // Set up all the video controls
            video_controls = new VideoControls ();
            video_controls.vexpand = true;
            video_controls.set_valign (Gtk.Align.END);
            video_controls.unfullscreen.connect (on_fullscreen_request);
            video_controls.play_toggled.connect (controller.play_pause);

            bottom_actor = new GtkClutter.Actor.with_contents (video_controls);
            stage.add_child (bottom_actor);

            var child1 = video_controls.get_child () as Gtk.Container;
            foreach (Gtk.Widget child in child1.get_children ()) {
                child.parent.get_style_context ().add_class ("video-toolbar");
                child.parent.parent.get_style_context ().add_class ("video-toolbar");
            }

            video_widget.motion_notify_event.connect (on_motion_event);

            return_to_library = new Gtk.Button.with_label (_ ("Return to Library"));
            return_to_library.get_style_context ().add_class ("video-widgets-background");
            return_to_library.has_tooltip = true;
            return_to_library.tooltip_text = _ ("Return to Library");
            return_to_library.relief = Gtk.ReliefStyle.NONE;
            return_to_library.margin = 5;
            return_to_library.set_no_show_all (false);
            return_to_library.show ();

            return_to_library.clicked.connect (on_return_to_library);

            return_revealer = new Gtk.Revealer ();
            return_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
            return_revealer.add (return_to_library);

            return_actor = new GtkClutter.Actor.with_contents (return_revealer);
            stage.add_child (return_actor);

            info ("Creating notebook.");

            notebook = new Gtk.Stack ();
            notebook.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            notebook.transition_duration = 200;

            info ("Creating podcast view.");

            details = new PodcastView (controller);
            details.go_back.connect (() => {
                switch_visible_page (all_scrolled);
            });

            info ("Creating welcome screen.");

            // Create a welcome screen and add it to the notebook (no matter if first run or not)

            welcome = new Granite.Widgets.Welcome (_("Welcome to Vocal"), _("Build Your Library By Adding Podcasts"));
            welcome.append(controller.on_elementary ? "preferences-desktop-online-accounts" : "applications-internet", _("Browse Podcasts"),
                 _("Browse through podcasts and choose some to add to your library."));
            welcome.append("list-add", _("Add a New Feed"), _("Provide the web address of a podcast feed."));
            welcome.append("document-open", _("Import Subscriptions"),
                    _("If you have exported feeds from another podcast manager, import them here."));
            welcome.append("emblem-synchronizing-symbolic", _("Sync With gpodder"), _("Log in to your gpodder.net account and synchronize your library."));
            
            welcome.activated.connect(on_welcome);
            info ("Creating new episodes view.");
            new_episodes_view = new NewEpisodesView (controller);
            new_episodes_view.go_back.connect (() => {
                switch_visible_page (all_scrolled);
            });
            new_episodes_view.play_episode_requested.connect ((episode) => {
                play_different_track (episode);
            });
            new_episodes_view.add_all_new_to_queue.connect ((episodes) => {
                foreach (Episode e in episodes) {
                    enqueue_episode (e);
                }
            });

            info ("Creating scrolled containers and album art views.");

            // Set up scrolled windows so that content will scoll instead of causing the window to expand
            all_scrolled = new Gtk.ScrolledWindow (null, null);
            directory_scrolled = new Gtk.ScrolledWindow (null, null);
            search_results_scrolled = new Gtk.ScrolledWindow (null, null);
            search_results_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            search_results_scrolled.add (search_results_box);

            // Set up the IconView for all podcasts
            all_flowbox = new Gtk.FlowBox ();
            all_art = new Gee.ArrayList<CoverArt> ();
            all_flowbox.get_style_context ().add_class ("notebook-art");
            all_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            all_flowbox.activate_on_single_click = true;
            all_flowbox.child_activated.connect (on_child_activated);
            all_flowbox.valign = Gtk.Align.START;
            all_flowbox.homogeneous = true;

            all_scrolled.add (all_flowbox);

            // Set up all the signals for the podcast view
            details.play_episode_requested.connect (play_different_track);
            details.download_episode_requested.connect (download_episode);
            details.enqueue_episode.connect (enqueue_episode);
            details.mark_episode_as_played_requested.connect (on_mark_episode_as_played_request);
            details.mark_episode_as_unplayed_requested.connect (on_mark_episode_as_unplayed_request);
            details.delete_local_episode_requested.connect (on_episode_delete_request);
            details.mark_all_episodes_as_played_requested.connect (on_mark_as_played_request);
            details.download_all_requested.connect (on_download_all_request);
            details.delete_podcast_requested.connect (on_remove_request);
            details.unplayed_count_changed.connect (on_unplayed_count_changed);
            details.new_cover_art_set.connect (on_new_cover_art_set);

            // Set up the box that gets displayed when importing from .OPML or .XML files during the first launch
            import_message_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 25);
            var import_h1_label = new Gtk.Label (_ ("Good Stuff is On Its Way"));
            var import_h3_label = new Gtk.Label (_ ("If you are importing several podcasts it can take a few minutes. Your library will be ready shortly."));
            import_h1_label.get_style_context ().add_class ("h1");
            import_h3_label.get_style_context ().add_class ("h3");
            import_h1_label.margin_top = 200;
            import_message_box.add (import_h1_label);
            import_message_box.add (import_h3_label);
            var spinner = new Gtk.Spinner ();
            spinner.active = true;
            spinner.start ();
            import_message_box.add (spinner);

            // Add everything into the notebook (except for the iTunes store and search view)
            notebook.add_titled (welcome, "welcome", _ ("Welcome"));
            notebook.add_titled (import_message_box, "import", _ ("Importing"));
            notebook.add_titled (all_scrolled, "all", _ ("All Podcasts"));
            notebook.add_titled (details, "details", _ ("Details"));
            notebook.add_titled (new_episodes_view, "new_episodes", _ ("New Episodes"));
            notebook.add_titled (video_widget, "video_player", _ ("Video"));

            bool show_complete_button = controller.first_run || controller.library.empty ();

            info ("Creating directory view.");

            directory = new DirectoryView (controller.itunes, controller.first_run);
            directory.load_top_podcasts ();
            directory.on_new_subscription.connect (on_new_subscription);
            directory.return_to_library.connect (on_return_to_library);
            directory.return_to_welcome.connect (() => {
                switch_visible_page (welcome);
            });
            directory_scrolled.add (directory);


            // Add the remaining widgets to the notebook. At this point, the gang's all here
            notebook.add_titled (directory_scrolled, "directory", _ ("Browse Podcast Directory"));
            notebook.add_titled (search_results_scrolled, "search", _ ("Search Results"));

            info ("Creating toolbar.");

            // Create the toolbar
            toolbar = new Toolbar (controller.settings);
            toolbar.get_style_context ().add_class ("vocal-headerbar");
            toolbar.search_button.clicked.connect (on_show_search);

            // Change the player position to match scale changes
            toolbar.playback_box.scale_changed.connect (() => {
                controller.player.set_progress (toolbar.playback_box.get_progress_bar_fill ());
            });

            toolbar.check_for_updates_selected.connect (() => {
                controller.on_update_request ();
            });

            toolbar.add_podcast_selected.connect (() => {
                add_new_podcast ();
            });

            toolbar.import_podcasts_selected.connect (() => {
                import_podcasts ();
            });

            toolbar.about_selected.connect (() => {
                controller.app.show_about (this);
            });

            toolbar.theme_toggled.connect (() => {
                if (controller.settings.dark_mode_enabled) {
                    Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", true);
                    style_context.remove_provider_for_screen (screen, headerbar_css_provider);
                } else {
                    Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", false);
                    style_context.add_provider_for_screen (screen, headerbar_css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                }
            });

            toolbar.preferences_selected.connect (() => {
                settings_dialog = new SettingsDialog (controller.settings, this);
                settings_dialog.show_name_label_toggled.connect (on_show_name_label_toggled);
                settings_dialog.show_all ();
            });

            toolbar.new_episodes_button.clicked.connect (() => {
                switch_visible_page (new_episodes_view);
            });
            
            toolbar.sync_dialog_selected.connect ( () => {
	    		sync_dialog = new SyncDialog(controller);
                sync_dialog.show_all ();
            });

            toolbar.refresh_selected.connect (controller.on_update_request);
            toolbar.play_pause_selected.connect (controller.play_pause);
            toolbar.seek_forward_selected.connect (controller.seek_forward);
            toolbar.seek_backward_selected.connect (controller.seek_backward);
            toolbar.playlist_button.clicked.connect (() => { artwork_popover.queue_box.show_all (); });

            toolbar.store_selected.connect (() => {
                details.pane_should_hide ();
                switch_visible_page (directory_scrolled);
            });

            toolbar.export_selected.connect (export_podcasts);
            toolbar.downloads_selected.connect (show_downloads_popover);

            toolbar.playback_box.volume_button.clicked.connect (() => {
                var popover = new Gtk.Popover (toolbar.playback_box.volume_button);

                var scale = new Gtk.Scale.with_range (Gtk.Orientation.VERTICAL, 0, 1, 0.1);
                scale.inverted = true;
                scale.draw_value = false;
                scale.margin = 5;
                scale.height_request = 120;
                scale.set_value (controller.player.get_volume ());
                scale.value_changed.connect (() => {
                    controller.player.set_volume (scale.get_value ());
                    if (scale.get_value () > 0.7) {
                        var vol_image = toolbar.playback_box.volume_button.image as Gtk.Image;
                        vol_image.icon_name = "audio-volume-high-symbolic";
                    } else if (scale.get_value () > 0.4) {
                        var vol_image = toolbar.playback_box.volume_button.image as Gtk.Image;
                        vol_image.icon_name = "audio-volume-medium-symbolic";
                    } else if (scale.get_value () > 0.1) {
                        var vol_image = toolbar.playback_box.volume_button.image as Gtk.Image;
                        vol_image.icon_name = "audio-volume-low-symbolic";
                    } else {
                        var vol_image = toolbar.playback_box.volume_button.image as Gtk.Image;
                        vol_image.icon_name = "audio-volume-muted-symbolic";
                    }
                });
                popover.add (scale);
                popover.show_all ();

            });

            // Repeat for the video playback box scale
            video_controls.progress_bar_scale_changed.connect (() => {
                controller.player.set_progress (video_controls.progress_bar_fill);
            });

            this.set_titlebar (toolbar);


            info ("Creating show notes popover.");

            // Create the show notes popover
            artwork_popover = new ArtworkPopover (toolbar.playback_box.artwork_image);
            toolbar.playback_box.artwork.button_press_event.connect ( () => {
            	artwork_popover.popup ();
            	artwork_popover.show_all ();
            	return false;
            });

            info ("Creating downloads popover.");
            downloads = new DownloadsPopover (toolbar.download);
            downloads.closed.connect (() => {
                if (downloads.downloads.size < 1)
                    toolbar.hide_downloads_menuitem ();
            });
            downloads.all_downloads_complete.connect (toolbar.hide_downloads_menuitem);

            info ("Creating queue popover.");
            
            // Create the queue popover
            controller.library.queue_changed.connect (() => {
                artwork_popover.queue_box.set_queue (controller.library.queue);
            });
            artwork_popover.queue_box.set_queue (controller.library.queue);
            artwork_popover.queue_box.move_up.connect ((e) => {
                controller.library.move_episode_up_in_queue (e);
                artwork_popover.queue_box.show_all ();
            });
            artwork_popover.queue_box.move_down.connect ((e) => {
                controller.library.move_episode_down_in_queue (e);
                artwork_popover.queue_box.show_all ();
            });
            artwork_popover.queue_box.update_queue.connect ((oldPos, newPos) => {
                controller.library.update_queue (oldPos, newPos);
                artwork_popover.queue_box.show_all ();
            });

            artwork_popover.queue_box.remove_episode.connect ((e) => {
                controller.library.remove_episode_from_queue (e);
                artwork_popover.queue_box.show_all ();
            });
            artwork_popover.queue_box.play_episode_from_queue_immediately.connect (play_episode_from_queue_immediately);

            info ("Adding notebook to window.");
            current_widget = notebook;
            
            var main_content_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            infobar = new Gtk.InfoBar();
            main_content_container.pack_start (infobar, false, false, 0);
            main_content_container.pack_start (notebook, true, true, 0);
            this.add (main_content_container);
            
            hide_infobar ();
            
            controller.update_status_changed.connect ( (currently_updating) => {
                if (currently_updating) {
                    show_infobar (_("Checking for new episodes…"), MessageType.INFO);
                } else {
                    hide_infobar ();
                }
            });

            // Create the search box
            search_results_view = new SearchResultsView (controller.library);
            search_results_view.on_new_subscription.connect (on_new_subscription);
            search_results_view.return_to_library.connect (() => {
                if (controller.library.empty ()) {
                    switch_visible_page (welcome);
                } else {
                    switch_visible_page (all_scrolled);
                }
            });
            search_results_view.episode_selected.connect (on_search_popover_episode_selected);
            search_results_view.podcast_selected.connect (on_search_popover_podcast_selected);

            search_results_box.add (search_results_view);

             if (controller.open_hidden) {
                info ("The app will open hidden in the background.");
                this.hide ();
            }
            info ("Window initialization complete.");
        }

        /*
         * Populates the three views (all, audio, video) from the contents of the controller.library
         */
        public void populate_views () {


            if (!controller.currently_repopulating) {

                info ("Populating the main podcast view.");
                controller.currently_repopulating = true;
                bool has_video = false;

                // If it's not the first run or newly launched go ahead and remove all the widgets from the flowboxes
                if (!controller.first_run && !controller.newly_launched) {
                    for (int i = 0; i < all_art.size; i++) {
                        all_flowbox.remove (all_flowbox.get_child_at_index (0));
                    }

                    all_art.clear ();
                }

                //TODO: Move this to the controller

                info ("Restoring last played media.");
                // If the program was just launched, check to see what the last played media was
                if (controller.newly_launched) {

                    current_widget = all_scrolled;

                    if (controller.settings.last_played_media != null && controller.settings.last_played_media.length > 1) {

                        // Split the media into two different strings
                        string[] fields = controller.settings.last_played_media.split (",");
                        bool found = false;
                        foreach (Podcast podcast in controller.library.podcasts) {

                            if (!found) {
                                if (podcast.name == fields[1]) {
                                    found = true;

                                    // Attempt to find the matching episode, set it as the current episode, and display the information in the box
                                    foreach (Episode episode in podcast.episodes) {
                                        if (episode.title == fields[0]) {
                                            controller.current_episode = episode;
                                            toolbar.playback_box.set_info_title (controller.current_episode.title.replace ("%27", "'"), controller.current_episode.parent.name.replace ("%27", "'"));
                                            toolbar.playback_box.set_artwork_image_image (controller.current_episode.parent.coverart_uri);
                                            controller.track_changed (controller.current_episode.title, controller.current_episode.parent.name, controller.current_episode.parent.coverart_uri, (uint64) controller.player.duration);

                                            try {

                                                controller.player.set_episode (controller.current_episode);
                                                controller.player.restore_position_episode = controller.current_episode;
                                                artwork_popover.set_notes_text (episode.description);

                                            } catch (Error e) {
                                                warning (e.message);
                                            }

                                            if (controller.current_episode.last_played_position != 0) {
                                                toolbar.show_playback_box ();
                                            }
                                            else {
                                                toolbar.hide_playback_box ();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }


                // Refill the controller.library based on what is stored in the database (if it's not newly launched, in
                // which case it has already been filled)
                if (!controller.newly_launched) {
                    info ("Refilling library.");
                    controller.library.refill_library ();
                }

                // Clear flags since we have an established controller.library at this point
                controller.newly_launched = false;
                controller.first_run = false;

                info ("Creating coverart for each podcast in library.");

                foreach (Podcast podcast in controller.library.podcasts) {

                    // Determine whether or not there are video podcasts
                    if (podcast.content_type == MediaType.VIDEO) {
                        has_video = true;
                    }

                    CoverArt a = new CoverArt (podcast.coverart_uri.replace ("%27", "'"), podcast, true);

                    if (controller.on_elementary) {
                        a.get_style_context ().add_class ("card");
                    } else {
                        a.get_style_context ().add_class ("coverart");
                    }
                    a.halign = Gtk.Align.START;

                    int currently_unplayed = 0;
                    foreach (Episode e in podcast.episodes) {
                        if (e.status == EpisodeStatus.UNPLAYED) {
                            currently_unplayed++;
                        }
                    }

                    if (currently_unplayed > 0) {
                        a.set_count (currently_unplayed);
                        a.show_count ();
                    }

                    else {
                        a.hide_count ();
                    }

                    all_art.add (a);

                }

                controller.currently_repopulating = false;
            }


            info ("Adding coverart to view.");

            foreach (CoverArt a in all_art) {
                all_flowbox.add (a);
            }

            var flowbox_children = all_flowbox.get_children ();
            foreach (Gtk.Widget f in flowbox_children) {
                f.halign = Gtk.Align.CENTER;
                f.valign = Gtk.Align.START;
            }

            new_episodes_view.populate_episodes_list ();

            // If the app is supposed to open hidden, don't present the window. Instead, hide it
            if (!controller.open_hidden && !controller.is_closing) {
                show_all ();
            }
        }

        /*
         * Populates the three views (all, audio, video) from the contents of the controller.library
         */
        public async void populate_views_async () {


            SourceFunc callback = populate_views_async.callback;

            ThreadFunc<void*> run = () => {

                populate_views ();

                Idle.add ((owned) callback);
                return null;
            };


            Thread.create<void*> (run, false);

            yield;
        }

        /*
         * When a user double-clicks and episode in the queue, remove it from the queue and
         * immediately begin playback
         */
        private void play_episode_from_queue_immediately (Episode e) {

            controller.current_episode = e;
            artwork_popover.queue_box.hide ();
            controller.library.remove_episode_from_queue (e);

            controller.play ();

            // Set the shownotes, the media information, and update the last played media in the settings
            controller.track_changed (controller.current_episode.title, controller.current_episode.parent.name, controller.current_episode.parent.coverart_uri, (uint64)controller.player.duration);
            artwork_popover.set_notes_text (controller.current_episode.description);
            controller.settings.last_played_media = "%s,%s".printf (controller.current_episode.title, controller.current_episode.parent.name);
        }

        /*
         * Switches the current track and requests the newly selected track starts playing
         */
        private void play_different_track (Episode? episode = null) {

            // Get the episode
            if (episode == null) {
                controller.current_episode = details.current_episode;
            } else {
                controller.current_episode = episode;
            }

            controller.player.pause ();
            controller.play ();

            // Set the shownotes, the media information, and update the last played media in the settings
            controller.track_changed (controller.current_episode.title, controller.current_episode.parent.name, controller.current_episode.parent.coverart_uri, (uint64) controller.player.duration);
            toolbar.playback_box.set_artwork_image_image (controller.current_episode.parent.coverart_uri);
            artwork_popover.set_notes_text (controller.current_episode.description);
            controller.settings.last_played_media = "%s,%s".printf (controller.current_episode.title, controller.current_episode.parent.name);
        }

        /*
         * Library functions
         */

        public async void mark_all_as_played_async (Podcast highlighted_podcast) {

            SourceFunc callback = mark_all_as_played_async.callback;

            ThreadFunc<void*> run = () => {

                controller.library.mark_all_episodes_as_played (highlighted_podcast);
                controller.library.recount_unplayed ();
                controller.library.set_new_badge ();
                foreach (CoverArt a in all_art) {
                    if (a.podcast == highlighted_podcast) {
                        a.set_count (0);
                        a.hide_count ();
                    }
                }

                details.mark_all_played ();


                Idle.add ((owned) callback);
                return null;
            };
            Thread.create<void*> (run, false);

            yield;
        }


        /*
         * Handles request to download an episode, by showing the downloads menuitem and
         * requesting the download from the controller.library
         */
        public void download_episode (Episode episode) {
            //  Show the download menuitem
            toolbar.show_download_button ();

            //  Begin the process of downloading the episode (asynchronously)
            var details_box = controller.library.download_episode (episode);
            details_box.cancel_requested.connect (on_download_canceled);

            // Every time a new percentage is available re-calculate the overall percentage
            details_box.new_percentage_available.connect (() => {
                double overall_percentage = 1.0;

                foreach (DownloadDetailBox d in downloads.downloads) {
                    if (d.percentage > 0.0) {
                        overall_percentage *= d.percentage;
                    }
                }
            });

            //  Add the download to the downloads popup
            downloads.add_download(details_box);
            
        }


        public void enqueue_episode (Episode episode) {
            controller.library.enqueue_episode (episode);
        }


        /*
         * Show a dialog to add a single feed to the controller.library
         */
        public void add_new_podcast () {
            add_feed = new AddFeedDialog (this, controller.on_elementary);
            add_feed.response.connect (on_add_podcast_feed);
            add_feed.show_all ();
        }


        /*
         * Create a file containing the current controller.library subscription export
         */
        public void export_podcasts () {
            //Create a new file chooser dialog and allow the user to import the save configuration
            var file_chooser = new Gtk.FileChooserDialog ("Save Subscriptions to XML File",
                          this,
                          Gtk.FileChooserAction.SAVE,
                          _ ("Cancel"), Gtk.ResponseType.CANCEL,
                          _ ("Save"), Gtk.ResponseType.ACCEPT);

            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.set_filter_name (_ ("All files"));
            all_files_filter.add_pattern ("*");

            var opml_xml_filter = new Gtk.FileFilter ();
            opml_xml_filter.set_filter_name (_ ("OPML and XML files"));
            opml_xml_filter.add_mime_type ("application/xml");
            opml_xml_filter.add_mime_type ("text/x-opml+xml");

            file_chooser.add_filter (opml_xml_filter);
            file_chooser.add_filter (all_files_filter);

            //Modal dialogs are sexy :)
            file_chooser.modal = true;

            //If the user selects a file, get the name and parse it
            if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
                string file_name = (file_chooser.get_filename ());
                controller.library.export_to_OPML (file_name);
            }

            //If the user didn't select a file, destroy the dialog
            file_chooser.destroy ();
        }


        /*
         * Choose a file to import to the controller.library
         */
        public void import_podcasts (string? import_file = null) {

            controller.currently_importing = true;
            int decision = Gtk.ResponseType.NONE;
            bool run_pending_import = false;
            Gtk.FileChooserDialog file_chooser = null;
            string file_name;

            if (import_file == null) {

                file_chooser = new Gtk.FileChooserDialog ("Save Subscriptions to XML File",
                          this,
                          Gtk.FileChooserAction.SAVE,
                          _ ("Cancel"), Gtk.ResponseType.CANCEL,
                          _ ("Save"), Gtk.ResponseType.ACCEPT);

                var all_files_filter = new Gtk.FileFilter ();
                all_files_filter.set_filter_name (_ ("All files"));
                all_files_filter.add_pattern ("*");

                var opml_filter = new Gtk.FileFilter ();
                opml_filter.set_filter_name (_ ("OPML files"));
                opml_filter.add_mime_type ("text/x-opml+xml");

                file_chooser.add_filter (opml_filter);
                file_chooser.add_filter (all_files_filter);

                file_chooser.modal = true;

                decision = file_chooser.run ();
                file_name = file_chooser.get_filename ();

                file_chooser.destroy ();
            } else {
                run_pending_import = true;
                file_name = import_file;
            }

            //If the user selects a file, get the name and parse it
            if (decision == Gtk.ResponseType.ACCEPT || run_pending_import == true) {

                toolbar.show_playback_box ();

                // Hide the shownotes button
                toolbar.playback_box.hide_artwork_image ();
                toolbar.playback_box.hide_volume_button ();
                toolbar.hide_playlist_button ();

                if (current_widget == welcome) {
                    switch_visible_page (import_message_box);
                }

                var loop = new MainLoop ();
                controller.library.add_from_OPML (file_name, false, false, (obj, res) => {

                    Gee.ArrayList<string> failed_feed_list = controller.library.add_from_OPML.end (res);

                    if (!controller.player.playing) {
                        toolbar.hide_playback_box ();
                    }

                    if (failed_feed_list.size == 0) {
                        info ("Successfully imported all podcasts from OPML.");
                    } else {
                        string failed_feeds = "";
                        foreach (string failed_feed in failed_feed_list) {
                            failed_feeds = "%s\n %s".printf (failed_feeds, failed_feed);
                        }
                        string error_message = "Vocal was unable to import podcasts from the following feeds in the OPML file. \n%s\n".printf (failed_feeds);
                        warning (error_message);

                        var error_img = new Gtk.Image.from_icon_name ("dialog-error", Gtk.IconSize.DIALOG);

                        var add_err_dialog = new Gtk.MessageDialog (add_feed, Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR, Gtk.ButtonsType.OK, "");
                        add_err_dialog.response.connect ((response_id) => {
                            add_err_dialog.destroy ();
                        });
                        add_err_dialog.set_transient_for (this);
                        add_err_dialog.text = _ ("Error Importing from File");
                        add_err_dialog.secondary_text = error_message;
                        add_err_dialog.set_image (error_img);
                        add_err_dialog.show_all ();
                    }

                    populate_views_async ();

                    // Make the refresh and export items sensitive now
                    toolbar.export_item.sensitive = true;

                    toolbar.playback_box.show_artwork_image ();
                    toolbar.playback_box.show_volume_button ();
                    toolbar.show_playlist_button ();

                    if (current_widget == import_message_box) {
                        switch_visible_page (all_scrolled);
                    }

                    show_all ();

                    controller.currently_importing = false;

                    if (controller.player.playing) {
                        toolbar.playback_box.set_info_title (controller.current_episode.title.replace ("%27", "'"), controller.current_episode.parent.name.replace ("%27", "'"));
                        toolbar.playback_box.set_artwork_image_image (controller.current_episode.parent.coverart_uri);
                        video_controls.set_info_title (controller.current_episode.title.replace ("%27", "'"), controller.current_episode.parent.name.replace ("%27", "'"));
                    }

                    loop.quit ();
                });
                loop.run ();

                file_chooser.destroy ();
            }
        }


        /*
         * UI-related methods
         */

        /*
         * Called when a podcast is selected from an iconview. Creates and displays a new window containing
         * the podcast and episode information
         */
        public void show_details (Podcast current_podcast) {
            details.set_podcast (current_podcast);
            switch_visible_page (details);
        }


        /*
         * Shows the downloads popover
         */
        public void show_downloads_popover () {
            this.downloads.show_all ();
        }


        /*
         * Called when a different widget needs to be displayed in the notebook
         */
         public void switch_visible_page (Gtk.Widget widget) {

            if (current_widget != widget)
                previous_widget = current_widget;

            if (widget == all_scrolled) {
                notebook.set_visible_child (all_scrolled);
                current_widget = all_scrolled;
            }
            else if (widget == details) {
                notebook.set_visible_child (details);
                current_widget = details;
            }
            else if (widget == video_widget) {
                notebook.set_visible_child (video_widget);
                current_widget = video_widget;
            }
            else if (widget == import_message_box) {
                notebook.set_visible_child (import_message_box);
                current_widget = import_message_box;
            }
            else if (widget == search_results_scrolled) {
                notebook.set_visible_child (search_results_scrolled);
                current_widget = search_results_scrolled;
            }
            else if (widget == directory_scrolled) {
                notebook.set_visible_child (directory_scrolled);
                current_widget = directory_scrolled;
            }
            else if (widget == welcome) {
                notebook.set_visible_child (welcome);
                current_widget = welcome;
            }
            else if (widget == new_episodes_view) {
                notebook.set_visible_child (new_episodes_view);
                current_widget = new_episodes_view;
            }
            else {
                info ("Attempted to switch to a notebook page that didn't exist. This is likely a bug and might cause issues.");
            }
         }


        /*
         * Signal handlers and callbacks
         */


        /*
         * Called when the player attempts to play media but the necessary Gstreamer plugins are not installed.
         * Prompts user to install the plugins and then proceeds to handle the installation. Playback begins
         * once plugins are installed.
         */
        public void on_additional_plugins_needed (Gst.Message install_message) {
            warning ("Required GStreamer plugins were not found. Prompting to install.");
            missing_dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
                 _ ("Additional plugins are needed to play media. Would you like for Vocal to install them for you?"));

            missing_dialog.response.connect ((response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.YES:
                        missing_dialog.destroy ();
                        var plugins_are_installing = true;

                        var installer = Gst.PbUtils.missing_plugin_message_get_installer_detail (install_message);
                        var context = new Gst.PbUtils.InstallPluginsContext ();

                         // Since we can't do anything else anyways, go ahead and install the plugins synchronously
                         Gst.PbUtils.InstallPluginsReturn ret = Gst.PbUtils.install_plugins_sync ({ installer }, context);
                         if (ret == Gst.PbUtils.InstallPluginsReturn.SUCCESS) {
                            info ("Plugins have finished installing. Updating GStreamer registry.");
                            Gst.update_registry ();
                            plugins_are_installing = false;

                            info ("GStreamer registry updated, attempting to start playback using the new plugins...");

                            // Reset the controller.player
                            controller.player.current_episode = null;

                            controller.play ();
                         }

                        break;
                    case Gtk.ResponseType.NO:
                        break;
                }

                missing_dialog.destroy ();
            });
            missing_dialog.show ();
        }


        /*
         * Handles requests to add individual podcast feeds (either from welcome screen or
         * the add feed menuitem
         */
        public void on_add_podcast_feed (int response_id) {
            if (response_id == Gtk.ResponseType.OK) {
                controller.add_podcast_feed (add_feed.entry.get_text ());
            }

            // Destroy the add podcast dialog box
            add_feed.destroy ();
        }


        /*
         * Called whenever a child is activated (selected) in one of the three flowboxes.
         */
        public void on_child_activated (FlowBoxChild child) {
            Gtk.FlowBox parent = child.parent as Gtk.FlowBox;
            CoverArt art = parent.get_child_at_index (child.get_index ()).get_child () as CoverArt;
            parent.unselect_all ();
            this.current_episode_art = art;
            controller.highlighted_podcast = art.podcast;
            show_details (art.podcast);
        }


        /*
         * Called when the user requests to download all episodes from the sidepane
         */
        public void on_download_all_request () {
            // TODO: Warn user if too many (more than 50?) podcasts will be downloaded.
            foreach (Episode episode in controller.highlighted_podcast.episodes) {
                if (episode.current_download_status == DownloadStatus.NOT_DOWNLOADED) {
                    download_episode (episode);
                }
            }
        }


        /*
         * Mark the episode as not being downloaded
         */
         private void on_download_canceled (Episode episode) {

            if (details != null && episode.parent == details.podcast) {

                // Get the index for the episode in the list
                int index = details.get_box_index_from_episode (episode);

                // Set the box to show the downloads button
                if (index != -1) {
                    details.boxes[index].show_download_button ();
                }
            }
        }


        /*
         * Mark an episode as being downloaded
         */
        public void on_download_finished (Episode episode) {

            if (details != null && episode.parent == details.podcast) {
                details.shownotes.hide_download_button ();
            }
            
            // Update gpodder.net
            controller.gpodder_client.update_episode (episode, EpisodeAction.DOWNLOAD);
        }


        /*
		 * Called when an episode needs to be deleted (locally)
		 */
        private void on_episode_delete_request(Episode episode) {
            controller.library.delete_local_episode(episode);
            details.on_single_delete(episode);
            
            // Update gpodder.net
            controller.gpodder_client.update_episode (controller.current_episode, EpisodeAction.DELETE);
        }



        /*
         * Called when the app needs to go fullscreen or unfullscreen
         */
        public void on_fullscreen_request () {

            if (fullscreened) {
                unfullscreen ();
                video_controls.set_reveal_child (false);
                fullscreened = false;
                ignore_window_state_change = true;
            } else {

                fullscreen ();
                fullscreened = true;
            }
        }


        /*
         * Called during an import event when the parser has started parsing a new feed
         */
        public void on_import_status_changed (int current, int total, string title, bool from_sync) {
            show_all ();
            if (from_sync == false) {
            	show_infobar (_("Adding feed %d/%d: %s").printf (current, total, title), MessageType.INFO);
        	}
        }


        /*
         * Called when the user requests to mark a podcast as played from the controller.library via the right-click menu
         */
        public void on_mark_as_played_request () {

            if (controller.highlighted_podcast != null) {
                Gtk.MessageDialog msg = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO,
                     _ ("Are you sure you want to mark all episodes from '%s' as played?".printf (GLib.Markup.escape_text (controller.highlighted_podcast.name))));

                var image = new Gtk.Image.from_icon_name ("dialog-question", Gtk.IconSize.DIALOG);
                msg.image = image;
                msg.image.show_all ();

                msg.response.connect ((response_id) => {
                    switch (response_id) {
                        case Gtk.ResponseType.YES:
                            mark_all_as_played_async (controller.highlighted_podcast);
                            break;
                        case Gtk.ResponseType.NO:
                            break;
                    }

                    msg.destroy ();
                });
                msg.show ();
            }
        }




        /*
         * Called when an episode needs to be marked as played
         */
        public void on_mark_episode_as_played_request (Episode episode) {

            // First check to see the episode is already marked as unplayed
            if (episode.status != EpisodeStatus.PLAYED) {
                controller.library.mark_episode_as_played (episode);
                controller.library.new_episode_count--;
                controller.library.set_new_badge ();
                foreach (CoverArt a in all_art) {
                    if (a.podcast == details.podcast) {
                        a.set_count (details.unplayed_count);
                        if (details.unplayed_count > 0) {
                            a.show_count ();
                        } else {
                            a.hide_count ();
                        }
                    }
                }

                new_episodes_view.populate_episodes_list ();
            }
        }


        /*
         * Called when an episode needs to be marked as unplayed
         */
        public void on_mark_episode_as_unplayed_request (Episode episode) {

            // First check to see the episode is already marked as unplayed
            if (episode.status != EpisodeStatus.UNPLAYED) {
                controller.library.mark_episode_as_unplayed (episode);
                controller.library.new_episode_count++;
                controller.library.set_new_badge ();

                foreach (CoverArt a in all_art) {
                    if (a.podcast == details.podcast) {
                        a.set_count (details.unplayed_count);
                        if (details.unplayed_count > 0) {
                            a.show_count ();
                        } else {
                            a.hide_count ();
                        }
                    }
                }
                if (controller.highlighted_podcast.content_type == MediaType.AUDIO) {
                    foreach (CoverArt audio in all_art) {
                        if (audio.podcast == details.podcast) {
                            audio.set_count (details.unplayed_count);
                            if (details.unplayed_count > 0) {
                                audio.show_count ();
                            } else {
                                audio.hide_count ();
                            }
                        }
                    }
                }
                else {
                    foreach (CoverArt video in all_art) {
                        if (video.podcast == details.podcast) {
                            video.set_count (details.unplayed_count);
                            if (details.unplayed_count > 0) {
                                video.show_count ();
                            } else {
                                video.hide_count ();
                            }
                        }
                    }
                }

                new_episodes_view.populate_episodes_list ();
            }
        }


        /*
         * Called when the user moves the cursor when a video is playing
         */
        private bool on_motion_event (Gdk.EventMotion e) {

            // Figure out if you should just move the window
            if (mouse_primary_down) {
                mouse_primary_down = false;
                this.begin_move_drag (Gdk.BUTTON_PRIMARY,
                    (int)e.x_root, (int)e.y_root, e.time);

            } else {

                // Show the cursor again
                this.get_window ().set_cursor (null);

                bool hovering_over_headerbar = false,
                hovering_over_return_button = false,
                hovering_over_video_controls = false;

                int min_height, natural_height;
                video_controls.get_preferred_height (out min_height, out natural_height);


                // Figure out whether or not the cursor is over the video bar at the bottom
                // If so, don't actually hide the cursor
                if (fullscreened && e.y < natural_height) {
                    hovering_over_video_controls = true;
                } else {
                    hovering_over_video_controls = false;
                }


                // e.y starts at 0.0 (top) and goes for however long
                // If < 10.0, we can assume it's above the top of the video area, and therefore
                // in the headerbar area
                if (!fullscreened && e.y < 10.0) {
                    hovering_over_headerbar = true;
                }


                if (hiding_timer != 0) {
                    Source.remove (hiding_timer);
                }

                if (current_widget == video_widget) {

                    hiding_timer = GLib.Timeout.add (2000, () => {

                        if (current_widget != video_widget) {
                            this.get_window ().set_cursor (null);
                            return false;
                        }

                        if (!fullscreened && (hovering_over_video_controls || hovering_over_return_button)) {
                            hiding_timer = 0;
                            return true;
                        }

                        else if (hovering_over_video_controls || hovering_over_return_button) {
                            hiding_timer = 0;
                            return true;
                        }

                        video_controls.set_reveal_child (false);
                        return_revealer.set_reveal_child (false);

                        if (controller.player.playing && !hovering_over_headerbar) {
                            this.get_window ().set_cursor (new Gdk.Cursor (Gdk.CursorType.BLANK_CURSOR));
                        }

                        return false;
                    });


                    if (fullscreened) {
                        bottom_actor.width = stage.width;
                        bottom_actor.y = stage.height - natural_height;
                        video_controls.set_reveal_child (true);
                    }
                    return_revealer.set_reveal_child (true);

                }
            }

            return false;
        }


        /*
         * Called when the subscribe button is clicked either on the store or on a search page
         */
        public void on_new_subscription (string itunes_url) {

            // We are given an iTunes store URL. We need to get the actual RSS feed from  this
            string rss = controller.itunes.get_rss_from_itunes_url (itunes_url);

            controller.add_podcast_feed (rss);
        }


        /*
         * Called when the user requests to remove a podcast from the controller.library via the right-click menu
         */
        public void on_remove_request () {
            if (controller.highlighted_podcast != null) {
                Gtk.MessageDialog msg = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE,
                                                               _ ("Are you sure you want to remove '%s' from your controller.library?"),
                                                               controller.highlighted_podcast.name.replace ("%27", "'"));


                msg.add_button (_ ("No"), Gtk.ResponseType.NO);
                Gtk.Button delete_button = (Gtk.Button) msg.add_button (_ ("Yes"), Gtk.ResponseType.YES);
                delete_button.get_style_context ().add_class ("destructive-action");

                var image = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG);
                msg.image = image;
                msg.image.show_all ();

                msg.response.connect ((response_id) => {
                    switch (response_id) {
                        case Gtk.ResponseType.YES:
                            controller.library.remove_podcast (controller.highlighted_podcast);
                            controller.highlighted_podcast = null;
                            if ( controller.library.empty ()) {
                                switch_visible_page (welcome);
                            } else {
                                switch_visible_page (all_scrolled);
                                populate_views_async ();
                            }
                            break;

                        case Gtk.ResponseType.NO:
                            break;
                    }

                    msg.destroy ();
                });
                msg.show ();
            }
        }


        /*
         * Called when the video needs to be hidden and the library shown again
         */
        public void on_return_to_library () {

            // If fullscreen, first exit fullscreen so you won't be "trapped" in fullscreen mode
            if (fullscreened)
                on_fullscreen_request ();

            // It's possible this was triggered by the directory on a first run, so check
            // the new episodes button
            if (!controller.library.empty ()) {
                toolbar.new_episodes_button.set_no_show_all (false);
                toolbar.new_episodes_button.show ();
            }

            // Since we can't see the video any more pause playback if necessary
            if (current_widget == video_widget && controller.player.playing)
                controller.pause ();

            // If the library is empty, always return to the welcome screen.
            if (controller.library.empty ()) {
                previous_widget = welcome;
            }

            if (previous_widget == directory_scrolled || previous_widget == search_results_scrolled)
                previous_widget = all_scrolled;

            switch_visible_page (previous_widget);

            // Make sure the cursor is visible again
            this.get_window ().set_cursor (null);
        }

         /*
          * Called when the user clicks on a podcast in the search popover
          */
         private void on_search_popover_podcast_selected (Podcast p) {
            if (p != null) {
                bool found = false;
                int i = 0;
                while (!found && i < all_art.size) {
                    CoverArt a = all_art[i];
                    if (a.podcast.name == p.name) {
                        all_flowbox.unselect_all ();
                        this.current_episode_art = a;
                        controller.highlighted_podcast = a.podcast;
                        show_details (a.podcast);
                        found = true;
                    }
                    i++;
                }
            }
         }


         /*
          * Called when the user clickson an episode in the search popover
          */
         private void on_search_popover_episode_selected (Podcast p, Episode e) {
            if (p != null && e != null) {
                bool podcast_found = false;
                int i = 0;
                while (!podcast_found && i < all_art.size) {
                    CoverArt a = all_art[i];
                    if (a.podcast.name == p.name) {
                        all_flowbox.unselect_all ();
                        this.current_episode_art = a;
                        controller.highlighted_podcast = a.podcast;
                        show_details (a.podcast);
                        podcast_found = true;
                        details.select_episode (e);
                    }
                    i++;
                }
            }
         }


        /*
         * Shows a full search results listing
         */
        public void on_show_search () {
            switch_visible_page (search_results_scrolled);
            show_all ();
        }


        /*
         * Called when the user toggles the show name label setting.
         * Calls the show/hide label method for every cover art.
         */
        public void on_show_name_label_toggled () {
            if (controller.settings.show_name_label) {
                foreach (CoverArt a in all_art) {
                    a.show_name_label ();
                }
            } else {
                foreach (CoverArt a in all_art) {
                    a.hide_name_label ();
                }
            }
        }


        /*
         * Called when the player finishes a stream
         */
        public void on_stream_ended () {

            // hide the playback box and set the image on the pause button to play
            toolbar.hide_playback_box ();

            var playpause_image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            toolbar.set_play_pause_image (playpause_image);

            // If there is a video showing, return to the controller.library view
            if (controller.current_episode.parent.content_type == MediaType.VIDEO) {
                on_return_to_library ();
            }

            controller.player.current_episode.last_played_position = 0;
            controller.library.set_episode_playback_position (controller.player.current_episode);

            controller.playback_status_changed ("Stopped");

            controller.current_episode = controller.library.get_next_episode_in_queue ();

            if (controller.current_episode != null) {

                controller.play ();

                // Set the shownotes, the media information, and update the last played media in the settings
                controller.track_changed (controller.current_episode.title, controller.current_episode.parent.name, controller.current_episode.parent.coverart_uri, (uint64) controller.player.duration);
                artwork_popover.set_notes_text (controller.current_episode.description);
                controller.settings.last_played_media = "%s,%s".printf (controller.current_episode.title, controller.current_episode.parent.name);
            } else {
                controller.player.playing = false;
                controller.settings.last_played_media = "";
            }

            // Regenerate the new episode list in case the ended episode was one of the new episodes
            new_episodes_view.populate_episodes_list ();

        }


        /*
         * Called when the unplayed count changes and the banner count in the iconviews needs updated
         */
        public void on_unplayed_count_changed (int n) {
            foreach (CoverArt a in all_art) {
                if (a.podcast == details.podcast) {
                    a.set_count (n);
                    if (n > 0) {
                        a.show_count ();
                    } else {
                        a.hide_count ();
                    }
                }
            }
            if (controller.highlighted_podcast.content_type == MediaType.AUDIO) {
                foreach (CoverArt audio in all_art) {
                    if (audio.podcast == details.podcast) {
                        audio.set_count (n);
                        if (n > 0) {
                            audio.show_count ();
                        } else {
                            audio.hide_count ();
                        }
                    }
                }
            }
            else {
                foreach (CoverArt video in all_art) {
                    if (video.podcast == details.podcast) {
                        video.set_count (n);
                        if (n > 0)
                            video.show_count ();
                        else
                            video.hide_count ();
                    }
                }
            }
        }

        /*
         * Called when a user manually sets a new cover art file
         */
        public void on_new_cover_art_set (string path) {

            // Find the cover art in the controller.library and set the new image
            foreach (CoverArt a in all_art) {
                if (a.podcast == details.podcast) {
                    GLib.File cover = GLib.File.new_for_path (path);
                    InputStream input_stream = cover.read ();
                    var pixbuf = a.create_cover_image (input_stream);

                    a.image.pixbuf = pixbuf;

                    // Now copy the image to controller.library cache and set it in the db
                    controller.library.set_new_local_album_art (path, a.podcast);
                }
            }
        }

        /*
         * Requests the app to be taken fullscreen if the video widget
         * is double-clicked
         */
        private bool on_video_button_press_event (EventButton e) {
            mouse_primary_down = true;
            if (e.type == Gdk.EventType.2BUTTON_PRESS) {
                on_fullscreen_request ();
            }

            return false;
        }

        private bool on_video_button_release_event (EventButton e) {
            mouse_primary_down = false;
            return false;
        }

        /*
         * Handles responses from the welcome screen
         */
        private void on_welcome (int index) {

            // Show the store
            if (index == 0) {
                switch_visible_page (directory_scrolled);

                // Set the controller.library as the previous widget for return_to_library to work
                previous_widget = all_scrolled;
            }

            // Add a new feed
            if (index == 1 ) {
                add_feed = new AddFeedDialog (this, controller.on_elementary);
                add_feed.response.connect (on_add_podcast_feed);
                add_feed.show_all ();

            // Import from OPML
            } else if (index == 2) {

                // The import podcasts method will handle any errors
                import_podcasts ();

			// gpodder.net
            } else if (index == 3) {
            	if (sync_dialog == null) {
            		sync_dialog = new SyncDialog (controller);
            	}
            	sync_dialog.show_all ();
            }
        }


        /*
         * Saves the window height and width before closing, and decides whether to close or minimize
         * based on whether or not a track is currently playing
         */
        private bool on_window_closing () {

            controller.is_closing = true;

            // If flagged to quit immediately, return true to go ahead and do that.
            // This flag is usually only set when the user wants to exit while downloads
            // are active
            if (controller.should_quit_immediately) {
                return false;
            }

            int width, height;
            this.get_size (out width, out height);
            controller.settings.window_height = height;
            controller.settings.window_width = width;



            // Save the playback position
            if (controller.player.current_episode != null) {
                stdout.printf ("Setting the last played position to %s\n", controller.player.current_episode.last_played_position.to_string ());
                if (controller.player.current_episode.last_played_position != 0)
                    controller.library.set_episode_playback_position (controller.player.current_episode);
            }
            
            // Update gpodder.net if necessary
            controller.gpodder_client.update_episode (controller.current_episode, EpisodeAction.PLAY);

            // If an episode is currently playing and Vocal is set to keep playing in the background, hide the window
            if (controller.player.playing && controller.settings.keep_playing_in_background) {
                this.hide ();
                return true;
            } else if (downloads != null && downloads.downloads.size > 0) {
                //If there are downloads verify that the user wishes to exit and cancel the downloads
                var downloads_active_dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO, _ ("Vocal is currently downloading episodes. Exiting will cause the downloads to be canceled. Are you sure you want to exit?"));
                downloads_active_dialog.response.connect ((response_id) => {
                    downloads_active_dialog.destroy ();
                    if (response_id == Gtk.ResponseType.YES) {
                        controller.should_quit_immediately = true;
                        this.close ();
                    }
                });
                downloads_active_dialog.show ();
                return true;
            } else {
                // If no downloads are active and nothing is playing,
                // return false to allow other handlers to close the window.
                return false;
            }
        }

        /*
         * Handler for when the window state changes
         */
        private void on_window_state_changed (Gdk.WindowState state) {

            if (controller.open_hidden) {
                show_all ();
                controller.open_hidden = false;
            }

            if (ignore_window_state_change)
                return;

            bool maximized = (state & Gdk.WindowState.MAXIMIZED) == 0;

            if (!maximized && !fullscreened && current_widget == video_widget) {
                on_fullscreen_request ();
            }
        }
        
        public void show_infobar (string message, MessageType type) {
            infobar.set_no_show_all (false);
            infobar.show_all ();
   
            infobar.set_message_type (type);
            
            var content_area = infobar.get_content_area ();
            var old_children = content_area.get_children ();
            foreach (Widget w in old_children) {
                content_area.remove (w);
            }
            var message_label = new Gtk.Label (message);
            message_label.margin_left = 12;
            message_label.use_markup = true;
            content_area.add (message_label);
            
            infobar.revealed = true;
            infobar.show_all ();
        }
        
        public void hide_infobar () {
            infobar.revealed = false;
            hiding_timer = GLib.Timeout.add (500, () => {
                infobar.set_no_show_all (true);
                infobar.hide ();
                
                return false;
            });
        }
    }
}
