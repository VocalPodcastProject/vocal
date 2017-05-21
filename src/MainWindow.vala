/***
  BEGIN LICENSE

  Copyright (C) 2014-2017 Nathan Dyer <mail@nathandyer.me>
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

        private VocalApp            app;
        private VocalSettings       settings;
        private iTunesProvider      itunes;

        /* Signals */

        public signal void track_changed(string episode_title, string podcast_name, string artwork_uri, uint64 duration);
        public signal void playback_status_changed(string status);

        /* Primary widgets */

        private Toolbar             toolbar;
        private Gtk.Box             box;
        private Welcome             welcome;
        private Library             library;
        private Player              player;
        private DirectoryView       directory;
        private SearchResultsView   search_results_view;
        private Gtk.Stack           notebook;
        private PodcastView         details;
        private Gtk.Box             import_message_box;

        /* Secondary widgets */

        private AddFeedDialog       add_feed;
        private DownloadsPopover    downloads;
        private ShowNotesPopover    shownotes;
        private QueuePopover        queue_popover;
        private Gtk.MessageDialog   missing_dialog;
        private SettingsDialog      settings_dialog;
        private VideoControls       video_controls;
        private Gtk.Revealer        return_revealer;
        private Gtk.Button          return_to_library;
        private Gtk.Box             search_results_box;

        /* Icon views and related variables */

        private Gtk.FlowBox         all_flowbox;
        private Gtk.ScrolledWindow  all_scrolled;
        private Gtk.ScrolledWindow  directory_scrolled;
        private Gtk.ScrolledWindow  search_results_scrolled;

        /* Video playback */

        public Clutter.Actor        actor;
        public GtkClutter.Actor     bottom_actor;
        public GtkClutter.Actor     return_actor;
        public Clutter.Stage        stage;
        public GtkClutter.Embed     video_widget;

        /* Runtime flags */

        private bool                first_run;
        private bool                newly_launched;
        private bool                library_empty;
        private bool                fullscreened = false;
        private bool                should_quit_immediately = false;
        private bool                plugins_are_installing = false;
        private bool                checking_for_updates = false;
        private bool 				currently_repopulating = false;
        private bool                currently_importing = false;
        private bool                is_closing = false;
        private bool                mouse_primary_down = false;

        public bool                 on_elementary = false;
        public bool                 open_hidden = false;

        /* System */

        public  GnomeMediaKeys      mediakeys;
        private Gst.PbUtils.InstallPluginsContext context;

        /* References, pointers, and containers */

        public Episode              current_episode;
        private Podcast             highlighted_podcast;
        private CoverArt            current_episode_art;
        private Gtk.Widget          current_widget;
        private Gtk.Widget          previous_widget;
        private Gee.ArrayList<CoverArt>      all_art;


        /* Miscellaneous global variables */

        private string  installer;
        private int     minutes_elapsed_in_period;
        private uint    hiding_timer = 0;
        private bool    ignore_window_state_change = false;


		/*
		 * Constructor for the main window. Creates the window and gets everything going.
		 */
        public MainWindow (VocalApp app, bool? open_hidden = false) {

            const string ELEMENTARY_STYLESHEET = """

                @define-color colorPrimary #af81d6;

                .album-artwork {
                    border-color: shade (mix (rgb (255, 255, 255), #fff, 0.5), 0.9);
                    border-style: solid;
                    border-width: 3px;

                    background-color: #8e8e93;
                }

                .controls {
                    background-color: #FFF;
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
                    border-bottom: 0.3px solid white;
                }

                .notebook-art {
                    /*background-color: #D8D8D8;*/
                }

                .podcast-view-coverart {
                    box-shadow: 5px 5px 5px #777;
                    border-style: none;
                }

/*
                .podcast-view-description {
                    //font: open sans 10px;
                }
*/
                .podcast-view-toolbar {
                }


                .rate-button {
                    color: shade (#000, 1.60);
                }


                .sidepane-toolbar {
                    background-color: #fff;
                }

                .video-back-button {
                    color: #af81d6;
                }

                .video-toolbar * {
                    background-image: none;
                    background-color: #af81d6;
                }

                """;

            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_buffer (ELEMENTARY_STYLESHEET.data);
            var screen = Gdk.Screen.get_default();
            var style_context = this.get_style_context();
            style_context.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            this.set_application (app);

            this.open_hidden = open_hidden;

            if(open_hidden) {
                info("The app will open hidden in the background.");
            }

            // Flag this as being newly launched
            this.newly_launched = true;

            // Check whether or not we're running on elementary
            on_elementary = Utils.check_elementary();
            if (!on_elementary) {
                Gtk.Settings.get_default().set("gtk-application-prefer-dark-theme", true);
            }

            // Grab the current settings
            this.settings = VocalSettings.get_default_instance();

            // Set window properties
            this.set_default_size (settings.window_width, settings.window_height);
            this.window_position = Gtk.WindowPosition.CENTER;

            // Set up the close event
            this.delete_event.connect(on_window_closing);
            this.window_state_event.connect ((e) => {
                if(!ignore_window_state_change) {
                    on_window_state_changed (e.window.get_state ());
                } else {
                    unmaximize();
                }
                ignore_window_state_change = false;
                return false;
            });


            // Create the Player and Initialize GStreamer
            player = Player.get_default(app.args);
            player.eos.connect(on_stream_ended);
            player.additional_plugins_required.connect(on_additional_plugins_needed);

            // Create the drawing area for the video widget
            video_widget = new GtkClutter.Embed();
            video_widget.use_layout_size = false;
            video_widget.button_press_event.connect(on_video_button_press_event);
            video_widget.button_release_event.connect(on_video_button_release_event);

            stage = (Clutter.Stage)video_widget.get_stage ();
            stage.background_color = {0, 0, 0, 0};
            stage.use_alpha = true;

            actor = new Clutter.Actor();
            var aspect_ratio = new ClutterGst.Aspectratio();
            ((ClutterGst.Content) aspect_ratio).player = player;
            actor.content = aspect_ratio;

            actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));
            stage.add_child (actor);

            // Set up all the video controls
            video_controls = new VideoControls();

            video_controls.vexpand = true;
            video_controls.set_valign (Gtk.Align.END);
            video_controls.unfullscreen.connect(on_fullscreen_request);
            video_controls.play_toggled.connect(play_pause);

            bottom_actor = new GtkClutter.Actor.with_contents (video_controls);
            stage.add_child(bottom_actor);

            var child1 = video_controls.get_child() as Gtk.Container;
            foreach(Gtk.Widget child in child1.get_children()) {
                child.parent.get_style_context().add_class("video-toolbar");
                child.parent.parent.get_style_context().add_class("video-toolbar");
            }

            video_widget.motion_notify_event.connect(on_motion_event);

            return_to_library = new Gtk.Button.with_label (_("Return to Library"));
            return_to_library.get_style_context().add_class("video-back-button");
            return_to_library.has_tooltip = true;
            return_to_library.tooltip_text = _("Return to Library");
            return_to_library.relief = Gtk.ReliefStyle.NONE;
            return_to_library.margin = 5;
            return_to_library.set_no_show_all(false);
            return_to_library.show();

            return_to_library.clicked.connect(on_return_to_library);

            return_revealer = new Gtk.Revealer();
            return_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
            return_revealer.add(return_to_library);

            return_actor = new GtkClutter.Actor.with_contents (return_revealer);
            stage.add_child(return_actor);

            // Set up the MPRIS playback functionality
            MPRIS mpris = new MPRIS(this);
            mpris.initialize();

            // Create the library
            library = new Library(this);

            // Connect the library's signals
            library.import_status_changed.connect(on_import_status_changed);
            library.download_finished.connect(on_download_finished);

            // Determine whether or not the local library exists
            first_run = (!library.check_database_exists());

            library_empty = false;

            // If the database exists refill the library and make sure that there's
            // actually something in it to display. If not, re-show the welcome screen
            if(!first_run) {
                library.refill_library();
                if(library.podcasts.size < 1) {
                    library_empty = true;

                }
            }

            // If this is the first run, create the directories and establish the database
            if(first_run) {
                library.setup_library();
            }

            // Initialize notifications (if libnotify is present and enabled)
#if HAVE_LIBNOTIFY
            Notify.init("Vocal");
#endif

            // Create the toolbar
            toolbar = new Toolbar (settings);
            toolbar.get_style_context().add_class("vocal-headerbar");
            toolbar.search_button.clicked.connect (on_show_search);

            // Connect the new player position available signal from the player
            // to set the new progress on the playback box
            player.new_position_available.connect(() => {

                if(player.progress > 0)
                    player.current_episode.last_played_position = player.progress;

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

                if(!currently_importing && player.progress != 0) {
                    toolbar.playback_box.set_progress(player.progress, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);
                    video_controls.set_progress(player.progress, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);
                }
            });


            // Set minutes elapsed to zero since the app is just now starting up
            minutes_elapsed_in_period = 0;

            // Automatically check for new episodes
            if(settings.update_interval != 0) {

                //Increase count and check for match every 5 minutes
                GLib.Timeout.add(300000, () => {

                    // The update interval increases/decreases by a step of 5 each time, so eventually
                    // the current count will equal the update interval. When that happens, update.
                    minutes_elapsed_in_period += 5;
                    if(minutes_elapsed_in_period == settings.update_interval) {
                        on_update_request();
                    }

                    return true;
                });
            }

            // Change the player position to match scale changes
            toolbar.playback_box.scale_changed.connect( () => {

                // Set the position
                player.set_position (toolbar.playback_box.get_progress_bar_fill());
            });

            // Repeat for the video playback box scale
            video_controls.progress_bar_scale_changed.connect( () => {

                // Set the position
                player.set_position (video_controls.progress_bar_fill);
            });

            // Set up media keys and keyboard shortcuts
            try {
                mediakeys = Bus.get_proxy_sync (BusType.SESSION,
                    "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                mediakeys.MediaPlayerKeyPressed.connect ( (bus, app, key) => {
                    if (app != "vocal")
                       return;
                    switch (key) {
                        case "Previous":
                            seek_backward();
                            break;
                        case "Next":
                            seek_forward();
                            break;
                        case "Play":
                            play_pause();
                            break;
                        default:
                            break;
                    }
                });

                mediakeys.GrabMediaPlayerKeys("vocal", 0);
            } catch (Error e) { warning (e.message); }


            // Set up all the keyboard shortcuts
            this.key_press_event.connect ( (e) => {
                bool handled = false;

                // Was the control key pressed?
                if((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    switch (e.keyval) {
                        case Gdk.Key.q:
                            this.destroy();
                            handled = true;
                            break;
                        case Gdk.Key.f:
                            on_show_search ();
                            handled = true;
                            break;
                        default:
                            break;
                    }
                }
                else {
                    switch (e.keyval) {
                        case Gdk.Key.space:
                            if(!search_results_view.search_entry.has_focus) {
                                play_pause();
                                handled = true;
                            }

                            break;
                        case Gdk.Key.F11:
                            on_fullscreen_request();
                            handled = true;
                            break;
                        case Gdk.Key.Escape:
                            if(fullscreened) {
                                on_fullscreen_request();
                                handled = true;
                            }

                            break;

                        case Gdk.Key.Left:
                            if(!search_results_view.search_entry.has_focus) {
                                seek_backward();
                                handled = true;
                            }
                            break;
                        case Gdk.Key.Right:
                            if(!search_results_view.search_entry.has_focus) {
                                seek_forward();
                                handled = true;
                            }
                            break;
                        }
                }

                return handled;
            });

            // box is just a generic container that will hold everything else (Gtk.Window can only directly hold a single child)
            box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Add everything to window
            this.add (box);
            this.set_titlebar(toolbar);

            // Create the show notes popover
            shownotes = new ShowNotesPopover(toolbar.shownotes_button);
            toolbar.shownotes_button.clicked.connect(() => { shownotes.show_all(); });

            downloads = new DownloadsPopover(toolbar.download);
            downloads.closed.connect(() => {
                if(downloads.downloads.size < 1)
                    toolbar.hide_downloads_menuitem();
            });
            downloads.all_downloads_complete.connect(toolbar.hide_downloads_menuitem);

            // Create the queue popover
            queue_popover = new QueuePopover(toolbar.playlist_button);
            library.queue_changed.connect(() => {
                queue_popover.set_queue(library.queue);
            });
            queue_popover.set_queue(library.queue);
            queue_popover.move_up.connect((e) => {
                library.move_episode_up_in_queue(e);
                queue_popover.show_all();
            });
            queue_popover.move_down.connect((e) => {
                library.move_episode_down_in_queue(e);
                queue_popover.show_all();
            });
            queue_popover.remove_episode.connect((e) => {
                library.remove_episode_from_queue(e);
                queue_popover.show_all();
            });
            queue_popover.play_episode_from_queue_immediately.connect(play_episode_from_queue_immediately);
            toolbar.playlist_button.clicked.connect(() => { queue_popover.show_all(); });

            // Set up all the toolbar signals
            toolbar.check_for_updates_selected.connect(() => {
                on_update_request();
            });

            toolbar.add_podcast_selected.connect(() => {
                add_new_podcast();
            });

            toolbar.import_podcasts_selected.connect(() => {
                import_podcasts();
            });

            toolbar.about_selected.connect (() => {
                app.show_about (this);
            });

            toolbar.preferences_selected.connect(() => {
                settings_dialog = new SettingsDialog(settings, this);
                settings_dialog.show_name_label_toggled.connect(on_show_name_label_toggled);
                settings_dialog.show_all();
            });

            toolbar.refresh_selected.connect(on_update_request);
            toolbar.play_pause_selected.connect(play_pause);
            toolbar.seek_forward_selected.connect(seek_forward);
            toolbar.seek_backward_selected.connect(seek_backward);

            toolbar.store_selected.connect(() => {
                details.pane_should_hide();
                switch_visible_page(directory_scrolled);
            });

            toolbar.export_selected.connect(export_podcasts);
            toolbar.downloads_selected.connect(show_downloads_popover);

            setup_library_widgets();
        }


        /*
         * Creates and configures all widgets pertaining the the library view (called either after
         * the user successfully adds content to library for the first time, or at the start of a session
         * that is NOT the first run).
         */
        private void setup_library_widgets() {

            // Create a welcome screen and add it to the notebook (no matter if first run or not)
            welcome = new Granite.Widgets.Welcome (_("Welcome to Vocal"), _("Build Your Library By Adding Podcasts"));
            welcome.append(on_elementary ? "preferences-desktop-online-accounts" : "applications-internet", _("Browse Podcasts"),
                 _("Browse through podcasts and choose some to add to your library."));
            welcome.append("list-add", _("Add a New Feed"), _("Provide the web address of a podcast feed."));
            welcome.append("document-open", _("Import Subscriptions"),
                    _("If you have exported feeds from another podcast manager, import them here."));
            welcome.activated.connect(on_welcome);

            // Set up scrolled windows so that content will scoll instead of causing the window to expand
            all_scrolled = new Gtk.ScrolledWindow (null, null);
            directory_scrolled = new Gtk.ScrolledWindow (null, null);
            search_results_scrolled = new Gtk.ScrolledWindow(null, null);

            search_results_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            search_results_scrolled.add(search_results_box);

		    // Set up the IconView for all podcasts
		    all_flowbox = new Gtk.FlowBox();
            all_art = new Gee.ArrayList<CoverArt>();
            all_flowbox.get_style_context().add_class("notebook-art");
            all_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            all_flowbox.activate_on_single_click = true;
            all_flowbox.child_activated.connect(on_child_activated);
            all_flowbox.valign = Gtk.Align.FILL;
            all_flowbox.homogeneous = true;

		    all_scrolled.add(all_flowbox);

            notebook = new Gtk.Stack();
            notebook.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            notebook.transition_duration = 300;

            details = new PodcastView (this, null, on_elementary);
            details.go_back.connect(() => {
                switch_visible_page(all_scrolled);
            });

            // Set up all the signals for the podcast view
            details.play_episode_requested.connect(play_different_track);
            details.download_episode_requested.connect(download_episode);
            details.enqueue_episode.connect(enqueue_episode);
            details.mark_episode_as_played_requested.connect(on_mark_episode_as_played_request);
            details.mark_episode_as_unplayed_requested.connect(on_mark_episode_as_unplayed_request);
            details.delete_local_episode_requested.connect(on_episode_delete_request);
            details.mark_all_episodes_as_played_requested.connect(on_mark_as_played_request);
            details.download_all_requested.connect(on_download_all_request);
            details.delete_podcast_requested.connect(on_remove_request);
            details.delete_multiple_episodes_requested.connect(on_delete_multiple_episodes);
            details.mark_multiple_episodes_as_played_requested.connect(on_mark_multiple_episodes_as_played);
            details.mark_multiple_episodes_as_unplayed_requested.connect(on_mark_multiple_episodes_as_unplayed);
            details.unplayed_count_changed.connect(on_unplayed_count_changed);
            details.new_cover_art_set.connect(on_new_cover_art_set);

            // Set up the box that gets displayed when importing from .OPML or .XML files during the first launch
            import_message_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 25);
            var import_h1_label = new Gtk.Label(_("Good Stuff is On Its Way"));
            var import_h3_label = new Gtk.Label(_("If you are importing several podcasts it can take a few minutes. Your library will be ready shortly."));
            Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H1, import_h1_label);
            Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H3, import_h3_label);
            import_h1_label.margin_top = 200;
            import_message_box.add(import_h1_label);
            import_message_box.add(import_h3_label);
            var spinner = new Gtk.Spinner();
            spinner.active = true;
            spinner.start();
            import_message_box.add(spinner);

            // Add everything into the notebook (except for the iTunes store and search view)
            notebook.add_titled(welcome, "welcome", _("Welcome"));
            notebook.add_titled(import_message_box, "import", _("Importing"));
            notebook.add_titled(all_scrolled, "all", _("All Podcasts"));
            notebook.add_titled(details, "details", _("Details"));
            notebook.add_titled(video_widget, "video_player", _("Video"));

            // Create the itunes directory and provider
            itunes = new iTunesProvider();
            bool show_complete_button = first_run || library_empty;
            directory = new DirectoryView(itunes, show_complete_button);
            directory.on_new_subscription.connect(on_new_subscription);
            directory.return_to_library.connect(on_return_to_library);
            directory.return_to_welcome.connect(() => {
                switch_visible_page(welcome);
            });
            directory_scrolled.add(directory);

            // Add the remaining widgets to the notebook. At this point, the gang's all here
            notebook.add_titled(directory_scrolled, "directory", _("Browse Podcast Directory"));
            notebook.add_titled(search_results_scrolled, "search", _("Search Results"));

            // Add the notebook
            var library_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		    library_box.pack_start(notebook, true, true, 0);

            // Add the thinpaned to the box
            box.pack_start(library_box, true, true, 0);
            current_widget = notebook;

            // Create the search box
            search_results_view = new SearchResultsView(library);
            search_results_view.on_new_subscription.connect(on_new_subscription);
            search_results_view.return_to_library.connect(() => {
                switch_visible_page(previous_widget);
            });
            search_results_view.episode_selected.connect(on_search_popover_episode_selected);
            search_results_view.podcast_selected.connect(on_search_popover_podcast_selected);

            search_results_box.add(search_results_view);

            show_all();

            // Show the welcome widget if it's the first run, or if the library is empty
            if(first_run || library_empty) {
                switch_visible_page(welcome);
                show_all();

            } else {
                // Populate the IconViews from the library
                populate_views();

                switch_visible_page(all_scrolled);

                
                if(open_hidden) {
                    this.hide();
                }

                // Autoclean the library
                if(settings.autoclean_library)
                    library.autoclean_library();

                // Check for updates after 20 seconds
                GLib.Timeout.add (20000, () => {
                    on_update_request();
                    return false;
                });

            }
        }

        /*
         * Populates the three views (all, audio, video) from the contents of the library
         */
        private async void populate_views() {

            SourceFunc callback = populate_views.callback;

            ThreadFunc<void*> run = () => {

            	if(!currently_repopulating)
            	{

            		currently_repopulating = true;
    	            bool has_video = false;

                    // If it's not the first run or newly launched go ahead and remove all the widgets from the flowboxes
                    if(!first_run && !newly_launched) {
        	            for(int i = 0; i < all_art.size; i++)
        	            {
        	            	all_flowbox.remove(all_flowbox.get_child_at_index(0));
        	            }

                        all_art.clear();
                    }


    	            // If the program was just launched, check to see what the last played media was
    	            if(newly_launched) {

                        current_widget = all_scrolled;

    	                if(settings.last_played_media != null && settings.last_played_media.length > 1) {

    	                    // Split the media into two different strings
    	                    string[] fields = settings.last_played_media.split(",");
    	                    bool found = false;
    	                    foreach(Podcast podcast in library.podcasts) {

    	                        if(!found) {
    	                            if(podcast.name == fields[1]) {
    	                                found = true;

    	                                // Attempt to find the matching episode, set it as the current episode, and display the information in the box
    	                                foreach(Episode episode in podcast.episodes) {
    	                                    if(episode.title == fields[0]){
    	                                        this.current_episode = episode;
    	                                        toolbar.playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
    	                                        track_changed(current_episode.title, current_episode.parent.name, current_episode.parent.coverart_uri, (uint64) player.duration);

    	                                        string new_uri;

    	                                        // Determine how long the track is and set the progress bar to match
    	                                        if(this.current_episode.local_uri != null) {
    	                                            new_uri = """file://""" + this.current_episode.local_uri;
    	                                        } else {
    	                                            new_uri = this.current_episode.uri;
    	                                        }

    	                                        bool episode_finished = false;
    	                                        try {

    	                                            player.set_episode(this.current_episode);

    	                                            //toolbar.playback_box.set_progress(percentage, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);
    	                                            shownotes.set_notes_text(episode.description);

    	                                        } catch(Error e) {
    	                                            warning(e.message);
    	                                        }

    	                                        if(current_episode.last_played_position != 0 && !episode_finished) {
    	                                            toolbar.show_playback_box();
    	                                        }
    	                                        else {
    	                                            toolbar.hide_playback_box();
    	                                        }
    	                                    }
    	                                }
    	                            }
    	                        }
    	                    }
    	                }
    	            }


    	            // Refill the library based on what is stored in the database (if it's not newly launched, in
    	            // which case it has already been filled)
    	            if(!newly_launched){
    	                library.refill_library();
    	            }

    	            // Clear flags since we have an established library at this point
    	            newly_launched = false;
    	            first_run = false;
    	            library_empty = false;

	                foreach(Podcast podcast in library.podcasts) {

	                    // Determine whether or not there are video podcasts
	                    if(podcast.content_type == MediaType.VIDEO) {
	                        has_video = true;
	                    }

                        CoverArt a = new CoverArt(podcast.coverart_uri.replace("%27", "'"), podcast, true);
                        a.get_style_context().add_class("coverart");
                        a.halign = Gtk.Align.START;

                        int currently_unplayed = 0;
                        foreach(Episode e in podcast.episodes)
                        {
                            if (e.status == EpisodeStatus.UNPLAYED)
                            {
                                currently_unplayed++;
                            }
                        }

                        if(currently_unplayed > 0)
                        {
                            a.set_count(currently_unplayed);
                            a.show_count();
                        }

                        else
                        {
                            a.hide_count();
                        }

                        all_art.add(a);
	                }

    	            currently_repopulating = false;
            	}

                    Idle.add((owned) callback);
                    return null;
                };


            Thread.create<void*>(run, false);

            yield;

            foreach(CoverArt a in all_art) {
                all_flowbox.add(a);
            }

            var flowbox_children = all_flowbox.get_children();
            foreach(Gtk.Widget f in flowbox_children) {
                f.halign = Gtk.Align.CENTER;
                f.valign = Gtk.Align.START;
            }

            // If the app is supposed to open hidden, don't present the window. Instead, hide it
            if(!open_hidden && !is_closing)
                show_all();
        }


        /*
         * Playback related methods
         */

        /*
         * Determines whether the play button should play or pause, and calls
         * the appropriate function
         */

        public void play_pause() {

            // If the player is playing, pause. Otherwise, play
            if(player != null) {
                if(player.playing) {
                    pause();
                } else {
                    play();
                }
            }
        }


        /*
         * Handles play requests and starts media playback using the player
         */
        public void play() {

            if(current_episode != null) {
                toolbar.show_playback_box();

                //If the current episode is unplayed, subtract one from unplayed total and display
                if(current_episode.status == EpisodeStatus.UNPLAYED) {
                    this.current_episode_art.set_count(this.details.unplayed_count);
                    if(this.details.unplayed_count > 0)
                        this.current_episode_art.show_count();
                    else
                        this.current_episode_art.hide_count();
                    library.new_episode_count--;
                    library.set_new_badge();
                }

                // Mark the current episode as played
                library.mark_episode_as_played(current_episode);

                // If the currently selected episode isn't set, do so
                if(player.current_episode != current_episode) {

                    // Save the position information from the previous episode
                    if(player.current_episode != null) {
                        library.set_episode_playback_position(player.current_episode);
                    }

                    player.set_episode(current_episode);
                }


                // Are we playing a video? If so, is the video widget already being displayed?
                if(player.current_episode.parent.content_type == MediaType.VIDEO && current_widget != video_widget) {

                    // If you want to see a pretty animation, you must give the player time to configure everything
                    GLib.Timeout.add (1000, () => {
                        switch_visible_page(video_widget);

                        return false;
                    });
                }

                player.play();
                playback_status_changed("Playing");

                // Seek if necessary
                if(current_episode.last_played_position > 0 && current_episode.last_played_position > player.progress) {

                    // If it's a streaming episode, seeking takes longer
                    // Temporarily pause the track and give it some time to seek
                    if(current_episode.current_download_status == DownloadStatus.NOT_DOWNLOADED) {
                        player.pause();
                    }

                    player.set_position(current_episode.last_played_position);

                    // Pause for about a second to give time to catch up
                    if(current_episode.current_download_status == DownloadStatus.NOT_DOWNLOADED) {
                        player.pause();
                        Thread.usleep(700000);
                        player.play();
                    }
                }

                var playpause_image = new Gtk.Image.from_icon_name("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                toolbar.set_play_pause_image(playpause_image);
                toolbar.set_play_pause_text(_("Pause"));

                var video_playpause_image = new Gtk.Image.from_icon_name("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                video_controls.play_button.image = video_playpause_image;
                video_controls.tooltip_text = _("Pause");
            

                // Set the media information (assuming we're not importing. If we are, the import status is more important
                // and the media info will be correctly set after it is finished.)
                if(!currently_importing) {
                    toolbar.playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                    video_controls.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                    shownotes.set_notes_text(current_episode.description);
                }
                show_all();
            }
        }

        /* Pauses playback if it is currently playing */
        public void pause() {

            // If we are playing, switch to paused mode.
            if(player.playing) {
                player.pause();
                playback_status_changed("Paused");
                var playpause_image = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                toolbar.set_play_pause_image(playpause_image);
                toolbar.set_play_pause_text(_("Play"));

                var video_playpause_image = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                video_controls.play_button.image = video_playpause_image;
                video_controls.tooltip_text = _("Play");

                // Set last played position
                current_episode.last_played_position = player.progress;
                library.set_episode_playback_position(player.current_episode);
            }

            // Set the media information (assuming we're not importing. If we are, the import status is more important
            // and the media info will be correctly set after it is finished.)
            if(!currently_importing) {
                toolbar.playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                video_controls.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                shownotes.set_notes_text(current_episode.description);
            }

            show_all();
        }


        /*
         * Switches the current track and requests the newly selected track starts playing
         */
        private void play_different_track () {

            // Get the episode
            int index = details.current_episode_index;
            current_episode = details.podcast.episodes[index];

            stdout.puts("settings state\n");

            player.pause();
            play();

            // Set the shownotes, the media information, and update the last played media in the settings
            track_changed(current_episode.title, current_episode.parent.name, current_episode.parent.coverart_uri, (uint64)player.duration);
            shownotes.set_notes_text(current_episode.description);
            settings.last_played_media = "%s,%s".printf(current_episode.title, current_episode.parent.name);
        }


        /*
         * When a user double-clicks and episode in the queue, remove it from the queue and
         * immediately begin playback
         */
        private void play_episode_from_queue_immediately(Episode e) {

            current_episode = e;
            queue_popover.hide();
            library.remove_episode_from_queue(e);

            play();

            // Set the shownotes, the media information, and update the last played media in the settings
            track_changed(current_episode.title, current_episode.parent.name, current_episode.parent.coverart_uri, (uint64)player.duration);
            shownotes.set_notes_text(current_episode.description);
            settings.last_played_media = "%s,%s".printf(current_episode.title, current_episode.parent.name);
        }


        /*
         * Seeks backward using the player by the number of settings specified in settings
         */
        public void seek_backward () {
            player.seek_backward(settings.rewind_seconds);
        }

        /*
         * Seeks forward using the player by the number of settings specified in settings
         */
        public void seek_forward () {
            player.seek_forward(settings.fast_forward_seconds);
        }




        /*
         * Library functions
         */


        /*
         * Handles request to download an episode, by showing the downloads menuitem and
         * requesting the download from the library
         */
        private void download_episode(Episode episode) {

            // Show the download menuitem
            toolbar.show_download_button();


            // Begin the process of downloading the episode (asynchronously)
            var details_box = library.download_episode(episode);
            details_box.cancel_requested.connect(on_download_canceled);

            // Every time a new percentage is available re-calculate the overall percentage
            details_box.new_percentage_available.connect(() => {
                double overall_percentage = 1.0;

                foreach(DownloadDetailBox d in downloads.downloads) {
                    if(d.percentage > 0.0) {
                        overall_percentage *= d.percentage;
                    }
                }

                // Commenting out setting launcher progress until it stops killing Plank
                //library.set_launcher_progress(overall_percentage);
            });


            // Add the download to the downloads popup
            downloads.add_download(details_box);
        }


        private void enqueue_episode (Episode episode) {
            library.enqueue_episode(episode);
        }


        /*
         * Show a dialog to add a single feed to the library
         */
        private void add_new_podcast() {
            add_feed = new AddFeedDialog(this, on_elementary);
            add_feed.response.connect(on_add_podcast_feed);
            add_feed.show_all();
        }


        /*
         * Create a file containing the current library subscription export
         */
        private void export_podcasts() {
            //Create a new file chooser dialog and allow the user to import the save configuration
            var file_chooser = new Gtk.FileChooserDialog ("Save Subscriptions to XML File",
                          this,
                          Gtk.FileChooserAction.SAVE,
                          _("Cancel"), Gtk.ResponseType.CANCEL,
                          _("Save"), Gtk.ResponseType.ACCEPT);

            var all_files_filter = new Gtk.FileFilter();
            all_files_filter.set_filter_name(_("All files"));
            all_files_filter.add_pattern("*");

            var opml_xml_filter = new Gtk.FileFilter();
            opml_xml_filter.set_filter_name(_("OPML and XML files"));
            opml_xml_filter.add_mime_type("application/xml");
            opml_xml_filter.add_mime_type("text/x-opml+xml");

            file_chooser.add_filter(opml_xml_filter);
            file_chooser.add_filter(all_files_filter);

            //Modal dialogs are sexy :)
            file_chooser.modal = true;

            //If the user selects a file, get the name and parse it
            if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
                string file_name = (file_chooser.get_filename ());
                library.export_to_OPML(file_name);
            }

            //If the user didn't select a file, destroy the dialog
            file_chooser.destroy ();
        }


        /*
         * Choose a file to import to the library
         */
        private void import_podcasts() {

            currently_importing = true;

            var file_chooser = new Gtk.FileChooserDialog (_("Select Subscription File"),
                 this,
                 Gtk.FileChooserAction.OPEN,
                 _("Cancel"), Gtk.ResponseType.CANCEL,
                 _("Open"), Gtk.ResponseType.ACCEPT);

            var all_files_filter = new Gtk.FileFilter();
            all_files_filter.set_filter_name(_("All files"));
            all_files_filter.add_pattern("*");

            var opml_filter = new Gtk.FileFilter();
            opml_filter.set_filter_name(_("OPML files"));
            opml_filter.add_mime_type("text/x-opml+xml");

            file_chooser.add_filter(opml_filter);
            file_chooser.add_filter(all_files_filter);

            file_chooser.modal = true;

            int decision = file_chooser.run();
            string file_name = file_chooser.get_filename();

            file_chooser.destroy();

            //If the user selects a file, get the name and parse it
            if (decision == Gtk.ResponseType.ACCEPT) {

                toolbar.show_playback_box();

                // Hide the shownotes button
                toolbar.hide_shownotes_button();
                toolbar.hide_playlist_button();

                if(current_widget == welcome) {
                    switch_visible_page(import_message_box);
                }

                var loop = new MainLoop();
                library.add_from_OPML(file_name, (obj, res) => {

                    bool success = library.add_from_OPML.end(res);

                    if(success) {

                        if(!player.playing)
                            toolbar.hide_playback_box();

                        // Is there now at least one podcast in the library?
                        if(library.podcasts.size > 0) {

                            // Make the refresh and export items sensitive now
                            toolbar.export_item.sensitive = true;

                            toolbar.show_shownotes_button();
                            toolbar.show_playlist_button();

                            populate_views();

                            if(current_widget == import_message_box) {
                                switch_visible_page(all_scrolled);
                            }

                            library_empty = false;

                            show_all();
                        }

                    } else {

                        if(!player.playing)
                            toolbar.hide_playback_box();

                        var add_err_dialog = new Gtk.MessageDialog(add_feed,
                            Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,
                            Gtk.ButtonsType.OK, "");
                            add_err_dialog.response.connect((response_id) => {
                                add_err_dialog.destroy();
                            });
                            
                        // Determine if it was a network issue, or just a problem with the feed
                        
                        bool network_okay = Utils.confirm_internet_functional();
                        
                        string error_message;
                        
                        if(network_okay) {
                            error_message = _("Please check that you selected the correct file and that it is not corrupted.");
                        } else {
                            error_message = _("There seems to be a problem with your internet connection. Make sure you are online and then try again.");
                        }

                        var error_img = new Gtk.Image.from_icon_name ("dialog-error", Gtk.IconSize.DIALOG);
                        add_err_dialog.set_transient_for(this);
                        add_err_dialog.text = _("Error Importing from File");
                        add_err_dialog.secondary_text = error_message;
                        add_err_dialog.set_image(error_img);
                        add_err_dialog.show_all();
                    }

                    currently_importing = false;

                    if(player.playing) {
                        toolbar.playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                        video_controls.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                    }

                    loop.quit();
                });
                loop.run();

                file_chooser.destroy();
            }
        }


        /*
         * UI-related methods
         */

        /*
         * Called when a podcast is selected from an iconview. Creates and displays a new window containing
         * the podcast and episode information
         */
        private void show_details (Podcast current_podcast) {
            details.set_podcast(current_podcast);
            switch_visible_page(details);
        }


        /*
         * Shows the downloads popover
         */
        private void show_downloads_popover() {
            this.downloads.show_all();
        }


        /*
         * Called when a different widget needs to be displayed in the notebook
         */
         private void switch_visible_page(Gtk.Widget widget) {

            if(current_widget != widget)
                previous_widget = current_widget;

            if (widget == all_scrolled) {
                notebook.set_visible_child(all_scrolled);
                current_widget = all_scrolled;
            }
            else if (widget == details) {
                notebook.set_visible_child(details);
                current_widget = details;
            }
            else if (widget == video_widget) {
                notebook.set_visible_child(video_widget);
                current_widget = video_widget;
            }
            else if (widget == import_message_box) {
                notebook.set_visible_child(import_message_box);
                current_widget = import_message_box;
            }
            else if (widget == search_results_scrolled) {
                notebook.set_visible_child(search_results_scrolled);
                current_widget = search_results_scrolled;
            }
            else if (widget == directory_scrolled) {
                notebook.set_visible_child(directory_scrolled);
                current_widget = directory_scrolled;
            }
            else if (widget == welcome) {
                notebook.set_visible_child(welcome);
                current_widget = welcome;
            }
            else {
                info("Attempted to switch to a notebook page that didn't exist. This is likely a bug and might cause issues.");
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
        private void on_additional_plugins_needed(Gst.Message install_message) {
            warning("Required GStreamer plugins were not found. Prompting to install.");
            missing_dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
                 _("Additional plugins are needed to play media. Would you like for Vocal to install them for you?"));

            missing_dialog.response.connect ((response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.YES:
                        missing_dialog.destroy();
                        plugins_are_installing = true;

                        installer = Gst.PbUtils.missing_plugin_message_get_installer_detail (install_message);
                        context = new Gst.PbUtils.InstallPluginsContext ();

                         // Since we can't do anything else anyways, go ahead and install the plugins synchronously
                         Gst.PbUtils.InstallPluginsReturn ret = Gst.PbUtils.install_plugins_sync ({ installer }, context);
                         if(ret == Gst.PbUtils.InstallPluginsReturn.SUCCESS) {
                            info("Plugins have finished installing. Updating GStreamer registry.");
                            Gst.update_registry ();
                            plugins_are_installing = false;

                            info("GStreamer registry updated, attempting to start playback using the new plugins...");

                            // Reset the player
                            player.current_episode = null;

                            play();
                         }

                        break;
                    case Gtk.ResponseType.NO:
                        break;
                }

                missing_dialog.destroy();
            });
            missing_dialog.show ();
        }


        /*
         * Handles requests to add individual podcast feeds (either from welcome screen or
         * the add feed menuitem
         */
        private void on_add_podcast_feed(int response_id) {
            add_podcast_feed(response_id, add_feed.entry.get_text(), null);
        }

        /*
         * Does the actual adding of podcast feeds
         */
        private void add_podcast_feed(int response_id, string feed, string? name) {

            currently_importing = true;

            if(response_id == Gtk.ResponseType.OK) {
                string entered_feed = "";
                if(feed == null && add_feed != null)
                    entered_feed = add_feed.entry.get_text();
                else
                    entered_feed = feed;

                // Was the RSS feed an iTunes URL? If so, find the actual RSS feed address
                if(entered_feed.contains("itunes.apple.com")) {
                    string actual_rss = itunes.get_rss_from_itunes_url(entered_feed);
                    if(actual_rss != null) {
                        info("Original iTunes URL: %s, Vocal found matching RSS address: %s", entered_feed, actual_rss);
                        entered_feed = actual_rss;
                    }
                }

                add_feed.destroy();

                // Hide the shownotes button
                toolbar.hide_shownotes_button();
                toolbar.hide_playlist_button();

                if(name == null)
                    toolbar.playback_box.set_message(_("Adding new podcast: <b>" + entered_feed + "</b>"));
                else
                    toolbar.playback_box.set_message(_("Adding new podcast: <b>" + name + "</b>"));
                toolbar.show_playback_box();

                var loop = new MainLoop();
                bool success = false;

                library.async_add_podcast_from_file(entered_feed, (obj, res) => {
                    success = library.async_add_podcast_from_file.end(res);
                    currently_importing = false;
                    if(player.playing) {
                        toolbar.playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                        video_controls.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                    }
                    loop.quit();
                });

                loop.run();

                if(success) {
                    toolbar.show_shownotes_button();
                    toolbar.show_playlist_button();

                    if(!player.playing)
                        toolbar.hide_playback_box();

                    // Is there now at least one podcast in the library?
                    if(library.podcasts.size > 0) {

                        // Make the refresh and export items sensitive now
                        //refresh_item.sensitive = true;
                        toolbar.export_item.sensitive = true;

                        // Populate views no matter what
                        populate_views();

                        if(current_widget == welcome) {
                            switch_visible_page(all_scrolled);
                        }

                        library_empty = false;

                        show_all();
                    }
                } else {

                    if(!player.playing)
                        toolbar.hide_playback_box();

                    var add_err_dialog = new Gtk.MessageDialog(add_feed,
                    Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,
                    Gtk.ButtonsType.OK, "");
                    add_err_dialog.response.connect((response_id) => {
                        add_err_dialog.destroy();
                    });
                    
                    // Determine if it was a network issue, or just a problem with the feed
                    
                    bool network_okay = Utils.confirm_internet_functional();
                    
                    string error_message;
                    
                    if(network_okay) {
                        error_message = _("Please make sure you selected the correct feed and that it is still available.");
                    } else {
                        error_message = _("There seems to be a problem with your internet connection. Make sure you are online and then try again.");
                    }

                    var error_img = new Gtk.Image.from_icon_name ("dialog-error", Gtk.IconSize.DIALOG);
                    add_err_dialog.set_transient_for(this);
                    add_err_dialog.text = _("Error Adding Podcast");
                    add_err_dialog.secondary_text = error_message;
                    add_err_dialog.set_image(error_img);
                    add_err_dialog.show_all();
                }

            }
            else {
            	// Destroy the add podcast dialog box
            	add_feed.destroy();
            }
        }


        /*
         * Called whenever a child is activated (selected) in one of the three flowboxes.
         */
        private void on_child_activated(FlowBoxChild child) {
            Gtk.FlowBox parent = child.parent as Gtk.FlowBox;
            CoverArt art = parent.get_child_at_index(child.get_index()).get_child() as CoverArt;
            parent.unselect_all();
            this.current_episode_art = art;
            this.highlighted_podcast = art.podcast;
            show_details(art.podcast);
        }


		/*
		 * Called when multiple episodes are highlighted in the sidepane and the user wishes to delete
		 */
        private void on_delete_multiple_episodes(Gee.ArrayList<int> indexes) {
            foreach(int i in indexes) {
                on_episode_delete_request(details.podcast.episodes[i]);
            }
        }


		/*
		 * Called when the user requests to download all episodes from the sidepane
		 */
        public void on_download_all_request() {
            foreach(Episode e in highlighted_podcast.episodes) {
                download_episode(e);
            }
        }


        /*
         * Mark the episode as not being downloaded
         */
         private void on_download_canceled(Episode episode) {

            if(details != null && episode.parent == details.podcast) {

                // Get the index for the episode in the list
                int index = details.get_box_index_from_episode(episode);

                // Set the box to show the downloads button
                if(index != -1) {
                    details.boxes[index].show_download_button();
                }
            }
        }


        /*
         * Mark an episode as being downloaded
         */
        private void on_download_finished(Episode episode) {

            if(details != null && episode.parent == details.podcast) {

                // Get the index for the episode in the list
                //int index = details.get_box_index_from_episode(episode);

                /*
                // Set the box to hide the downloads button
                if(index != -1) {
                    details.boxes[index].hide_download_button();
                    details.boxes[index].show_playback_button();
                } */

                details.shownotes.hide_download_button();
            }
        }


        /*
		 * Called when an episode needs to be deleted (locally)
		 */
        private void on_episode_delete_request(Episode episode) {
            library.delete_local_episode(episode);
            details.on_single_delete(episode);
        }



		/*
		 * Called when the app needs to go fullscreen or unfullscreen
		 */
        private void on_fullscreen_request() {

            if(fullscreened) {
                unfullscreen();
                video_controls.set_reveal_child(false);
                fullscreened = false;
                ignore_window_state_change = true;
            } else {

                fullscreen();
                fullscreened = true;
            }
        }


        /*
         * Called during an import event when the parser has started parsing a new feed
         */
        private void on_import_status_changed(int current, int total, string title) {
            show_all();
            toolbar.playback_box.set_message_and_percentage("Adding feed %d/%d: %s".printf(current, total, title), (double)((double)current/(double)total));
        }


        /*
         * Called when the user requests to mark a podcast as played from the library via the right-click menu
         */
        private void on_mark_as_played_request() {

            if(highlighted_podcast != null) {
                Gtk.MessageDialog msg = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO,
                     _("Are you sure you want to mark all episodes from '%s' as played?".printf(GLib.Markup.escape_text(highlighted_podcast.name.replace("%","%%")))));

                var image = new Gtk.Image.from_icon_name("dialog-question", Gtk.IconSize.DIALOG);
                msg.image = image;
                msg.image.show_all();

			    msg.response.connect ((response_id) => {
			        switch (response_id) {
				        case Gtk.ResponseType.YES:
                            mark_all_as_played_async(highlighted_podcast);
					        break;
				        case Gtk.ResponseType.NO:
					        break;
			        }

			        msg.destroy();
		        });
		        msg.show ();
	        }
        }

        private async void mark_all_as_played_async(Podcast highlighted_podcast) {

            SourceFunc callback = mark_all_as_played_async.callback;

            ThreadFunc<void*> run = () => {

                library.mark_all_episodes_as_played(highlighted_podcast);
                library.recount_unplayed();
                library.set_new_badge();
                foreach(CoverArt a in all_art)
                {
                    if(a.podcast == highlighted_podcast)
                    {
                        a.set_count(0);
                        a.hide_count();
                    }
                }

                details.mark_all_played();


                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);

            yield;
        }


        /*
		 * Called when an episode needs to be marked as played
		 */
        private void on_mark_episode_as_played_request(Episode episode) {

            // First check to see the episode is already marked as unplayed
            if(episode.status != EpisodeStatus.PLAYED) {
                library.mark_episode_as_played(episode);
                library.new_episode_count--;
                library.set_new_badge();
                foreach(CoverArt a in all_art)
                {
                    if(a.podcast == details.podcast)
                    {
                        a.set_count(details.unplayed_count);
                        if(details.unplayed_count > 0)
                            a.show_count();
                        else
                            a.hide_count();
                    }
                }
            }
        }


		/*
		 * Called when an episode needs to be marked as unplayed
		 */
        private void on_mark_episode_as_unplayed_request(Episode episode) {

            // First check to see the episode is already marked as unplayed
            if(episode.status != EpisodeStatus.UNPLAYED) {
                library.mark_episode_as_unplayed(episode);
                library.new_episode_count++;
                library.set_new_badge();

                foreach(CoverArt a in all_art)
                {
                    if(a.podcast == details.podcast)
                    {
                        a.set_count(details.unplayed_count);
                        if(details.unplayed_count > 0)
                            a.show_count();
                        else
                            a.hide_count();
                    }
                }
                if(highlighted_podcast.content_type == MediaType.AUDIO) {
                    foreach(CoverArt audio in all_art)
                    {
                        if(audio.podcast == details.podcast)
                        {
                            audio.set_count(details.unplayed_count);
                            if(details.unplayed_count > 0)
                                audio.show_count();
                            else
                                audio.hide_count();
                        }
                    }
                }
                else {
                    foreach(CoverArt video in all_art)
                    {
                        if(video.podcast == details.podcast)
                        {
                            video.set_count(details.unplayed_count);
                            if(details.unplayed_count > 0)
                                video.show_count();
                            else
                                video.hide_count();
                        }
                    }
                }
            }
        }


		/*
		 * Called when multiple episodes are highlighted in the sidepane and the user wishes to
		 * mark them all as played
		 */
        private void on_mark_multiple_episodes_as_played(Gee.ArrayList<int> indexes) {
            foreach(int i in indexes) {
                on_mark_episode_as_played_request(details.podcast.episodes[i]);
            }
        }


		/*
		 * Called when multiple episodes are highlighted in the sidepane and the user wishes to
		 * mark them all as played
		 */
        private void on_mark_multiple_episodes_as_unplayed(Gee.ArrayList<int> indexes) {
            foreach(int i in indexes) {
                on_mark_episode_as_unplayed_request(details.podcast.episodes[i]);
            }
        }


		/*
		 * Called when the user moves the cursor when a video is playing
		 */
        private bool on_motion_event(Gdk.EventMotion e) {

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
                video_controls.get_preferred_height(out min_height, out natural_height);


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

                if(current_widget == video_widget) {

                    hiding_timer = GLib.Timeout.add (2000, () => {

                        if(current_widget != video_widget)
                        {
                            this.get_window ().set_cursor (null);
                            return false;
                        }

                        if(!fullscreened && (hovering_over_video_controls || hovering_over_return_button)) {
                            hiding_timer = 0;
                            return true;
                        }

                        else if (hovering_over_video_controls || hovering_over_return_button) {
                            hiding_timer = 0;
                            return true;
                        }

                        video_controls.set_reveal_child(false);
                        return_revealer.set_reveal_child(false);

                        if(player.playing && !hovering_over_headerbar) {
                            this.get_window ().set_cursor (new Gdk.Cursor (Gdk.CursorType.BLANK_CURSOR));
                        }

                        return false;
                    });


                    if(fullscreened) {
                        bottom_actor.width = stage.width;
                        bottom_actor.y = stage.height - natural_height;
                        video_controls.set_reveal_child(true);
                    }
                    return_revealer.set_reveal_child(true);

                }
            }

            return false;
        }


        /*
         * Called when the subscribe button is clicked either on the store or on a search page
         */
        private void on_new_subscription(string itunes_url) {

            string name;

            // We are given an iTunes store URL. We need to get the actual RSS feed from  this
            string rss = itunes.get_rss_from_itunes_url(itunes_url, out name);

            if(name == null) {
                name = "Unknown";
            }

            add_podcast_feed(Gtk.ResponseType.OK, rss, name);
        }


        /*
         * Called when the user requests to remove a podcast from the library via the right-click menu
         */
        private void on_remove_request() {
            if(highlighted_podcast != null) {
                Gtk.MessageDialog msg = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE,
                     _("Are you sure you want to remove '%s' from your library?".printf(highlighted_podcast.name.replace("%27", "'"))));


                msg.add_button (_("No"), Gtk.ResponseType.NO);
                Gtk.Button delete_button = (Gtk.Button) msg.add_button(_("Yes"), Gtk.ResponseType.YES);
                delete_button.get_style_context().add_class("destructive-action");

                var image = new Gtk.Image.from_icon_name("dialog-warning", Gtk.IconSize.DIALOG);
                msg.image = image;
                msg.image.show_all();

			    msg.response.connect ((response_id) => {
			        switch (response_id) {
				        case Gtk.ResponseType.YES:
					        library.remove_podcast(highlighted_podcast);
					        highlighted_podcast = null;
                            switch_visible_page(all_scrolled);
                            populate_views();
					        break;
				        case Gtk.ResponseType.NO:
					        break;
			        }

			        msg.destroy();
		        });
		        msg.show ();
	        }
        }


        /*
         * Called when the video needs to be hidden and the library shown again
         */
        private void on_return_to_library() {

            // If fullscreen, first exit fullscreen so you won't be "trapped" in fullscreen mode
            if(fullscreened)
                on_fullscreen_request();

            // Since we can't see the video any more pause playback if necessary
            if(current_widget == video_widget && player.playing)
                pause();

            if(previous_widget == directory_scrolled || previous_widget == search_results_scrolled)
                previous_widget = all_scrolled;
            switch_visible_page(previous_widget);


            // Make sure the cursor is visible again
            this.get_window ().set_cursor (null);
        }

         /*
          * Called when the user clicks on a podcast in the search popover
          */
         private void on_search_popover_podcast_selected(Podcast p) {
            if(p != null) {
                bool found = false;
                int i = 0;
                while(!found && i < all_art.size) {
                    CoverArt a = all_art[i];
                    if(a.podcast.name == p.name) {
                        all_flowbox.unselect_all();
                        this.current_episode_art = a;
                        this.highlighted_podcast = a.podcast;
                        show_details(a.podcast);
                        found = true;
                    }
                    i++;
                }
            }
         }


         /*
          * Called when the user clickson an episode in the search popover
          */
         private void on_search_popover_episode_selected(Podcast p, Episode e) {
            if(p != null && e != null) {
                bool podcast_found = false;
                int i = 0;
                while(!podcast_found && i < all_art.size) {
                    CoverArt a = all_art[i];
                    if(a.podcast.name == p.name) {
                        all_flowbox.unselect_all();
                        this.current_episode_art = a;
                        this.highlighted_podcast = a.podcast;
                        show_details(a.podcast);
                        podcast_found = true;
                        details.select_episode(e);
                    }
                    i++;
                }
            }
         }


        /*
         * Shows a full search results listing
         */
        private void on_show_search() {
            switch_visible_page(search_results_scrolled);
            show_all();
        }


        /*
         * Called when the user toggles the show name label setting.
         * Calls the show/hide label method for every cover art.
         */
        private void on_show_name_label_toggled() {
            if(settings.show_name_label) {
                foreach(CoverArt a in all_art) {
                    a.show_name_label();
                }
            } else {
                foreach(CoverArt a in all_art) {
                    a.hide_name_label();
                }
            }
        }


        /*
         * Called when the player finishes a stream
         */
        private void on_stream_ended() {

            // hide the playback box and set the image on the pause button to play
            toolbar.hide_playback_box();

            var playpause_image = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            toolbar.set_play_pause_image(playpause_image);

            // If there is a video showing, return to the library view
            if(current_episode.parent.content_type == MediaType.VIDEO) {
                on_return_to_library();
            }

            player.current_episode.last_played_position = 0;
            library.set_episode_playback_position(player.current_episode);

            playback_status_changed("Stopped");


            current_episode = library.get_next_episode_in_queue();

            if(current_episode != null) {

                play();

                // Set the shownotes, the media information, and update the last played media in the settings
                track_changed(current_episode.title, current_episode.parent.name, current_episode.parent.coverart_uri, (uint64) player.duration);
                shownotes.set_notes_text(current_episode.description);
                settings.last_played_media = "%s,%s".printf(current_episode.title, current_episode.parent.name);
            } else {
                player.playing = false;
            }

        }


        /*
		 * Called when the unplayed count changes and the banner count in the iconviews needs updated
		 */
        private void on_unplayed_count_changed(int n) {
            foreach(CoverArt a in all_art)
                {
                    if(a.podcast == details.podcast)
                    {
                        a.set_count(n);
                        if(n > 0)
                            a.show_count();
                        else
                            a.hide_count();
                    }
                }
                if(highlighted_podcast.content_type == MediaType.AUDIO) {
                    foreach(CoverArt audio in all_art)
                    {
                        if(audio.podcast == details.podcast)
                        {
                            audio.set_count(n);
                            if(n > 0)
                                audio.show_count();
                            else
                                audio.hide_count();
                        }
                    }
                }
                else {
                    foreach(CoverArt video in all_art)
                    {
                        if(video.podcast == details.podcast)
                        {
                            video.set_count(n);
                            if(n > 0)
                                video.show_count();
                            else
                                video.hide_count();
                        }
                    }
                }
        }
        
        /*
         * Called when a user manually sets a new cover art file
         */
        private void on_new_cover_art_set(string path) {
            
            // Find the cover art in the library and set the new image
            foreach(CoverArt a in all_art) {
                if(a.podcast == details.podcast) {
                    GLib.File cover = GLib.File.new_for_path(path);
                    InputStream input_stream = cover.read();
                    var pixbuf = new Gdk.Pixbuf.from_stream_at_scale(input_stream, 275, 275, true);
                    
                    a.image.pixbuf = pixbuf;
                    
                    // Now copy the image to library cache and set it in the db
                    library.set_new_local_album_art(path, a.podcast);
                }
            }
        }


        /*
         * Check for new episodes
         */
        private void on_update_request() {

            // Only check for updates if no other checks are currently under way
            if(!checking_for_updates) {

                info("Checking for updates.");

                checking_for_updates = true;

                // Create an arraylist to store new episodes
                Gee.ArrayList<Episode> new_episodes = new Gee.ArrayList<Episode>();

                var loop = new MainLoop();
                library.check_for_updates.begin((obj, res) => {
                    try {
                        new_episodes = library.check_for_updates.end(res);
                    } catch (Error e) {
                        warning(e.message);
                    }
                    loop.quit();
                });
                loop.run();

                // Reset the period
                minutes_elapsed_in_period = 0;

                checking_for_updates = false;

                // Send a notification if there are new episodes
                if(new_episodes.size > 0 && !settings.auto_download)
                {
                    if(!focus_visible)
                	   Utils.send_generic_notification(_("Fresh content has been added to your library."));

                	// Also update the number of new episodes and set the badge count
                	library.new_episode_count += new_episodes.size;
                	library.set_new_badge();
                }

                // Automatically download episodes if set to do so
                if(settings.auto_download && new_episodes.size > 0) {
                    foreach(Episode e in new_episodes) {
                        download_episode(e);
                    }
                }

                int new_episode_count = new_episodes.size;

                // Free up the memory from the arraylist
                new_episodes = null;

                // Lastly, if there are new episodes, repopulate the views to obtain new counts
                if(new_episode_count > 0)
                    this.populate_views();
            } else {
                info("Vocal is already checking for updates.");
            }

        }

        /*
         * Requests the app to be taken fullscreen if the video widget
         * is double-clicked
         */
        private bool on_video_button_press_event(EventButton e) {
            mouse_primary_down = true;
            if(e.type == Gdk.EventType.2BUTTON_PRESS) {
                on_fullscreen_request();
            }

            return false;
        }

        private bool on_video_button_release_event(EventButton e) {
            mouse_primary_down = false;
            return false;
        }

        /*
         * Handles responses from the welcome screen
         */
        private void on_welcome(int index) {

            // Show the store
            if(index == 0) {
                switch_visible_page(directory_scrolled);

                // Set the library as the previous widget for return_to_library to work
                previous_widget = all_scrolled;
            }

            // Add a new feed
            if (index == 1 ) {
                add_feed = new AddFeedDialog(this, on_elementary);
                add_feed.response.connect(on_add_podcast_feed);
                add_feed.show_all();

            // Import from OPML
            } else if (index == 2) {

                // The import podcasts method will handle any errors
                import_podcasts();

            } 
        }


        /*
         * Saves the window height and width before closing, and decides whether to close or minimize
         * based on whether or not a track is currently playing
         */
        private bool on_window_closing() {

            is_closing = true;

        	// If flagged to quit immediately, return true to go ahead and do that.
        	// This flag is usually only set when the user wants to exit while downloads
        	// are active
        	if(should_quit_immediately) {
        		return false;
        	}

            int width, height;
            this.get_size(out width, out height);
            settings.window_height = height;
            settings.window_width = width;



            // Save the playback position
            if(player.current_episode != null) {
                stdout.printf("Setting the last played position to %s\n", player.current_episode.last_played_position.to_string());
                if(player.current_episode.last_played_position != 0)
                    library.set_episode_playback_position(player.current_episode);
            }

            // If an episode is currently playing, hide the window
            if(player.playing) {
                this.hide();
                return true;
            } else if(downloads != null && downloads.downloads.size > 0) {

            	//If there are downloads verify that the user wishes to exit and cancel the downloads
            	var downloads_active_dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO, _("Vocal is currently downloading episodes. Exiting will cause the downloads to be canceled. Are you sure you want to exit?"));
            	downloads_active_dialog.response.connect ((response_id) => {
            		downloads_active_dialog.destroy();
					if(response_id == Gtk.ResponseType.YES) {
						should_quit_immediately = true;
						this.close();
					}
				});
				downloads_active_dialog.show();
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
        private void on_window_state_changed(Gdk.WindowState state) {

            if(open_hidden) {
                show_all();
                open_hidden = false;
            }

            if(ignore_window_state_change)
                return;

            bool maximized = (state & Gdk.WindowState.MAXIMIZED) == 0;

            if(!maximized && !fullscreened && current_widget == video_widget) {
                on_fullscreen_request();
            }
        }
    }
}
