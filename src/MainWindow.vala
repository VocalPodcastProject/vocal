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

        /* Signals */

        public signal void track_changed(string episode_title, string podcast_name, string artwork_uri, uint64 duration);
        public signal void playback_status_changed(string status);
        
        /* Primary widgets */
        
        private Gtk.HeaderBar       toolbar;
        private Gtk.Menu            menu;
        private Gtk.MenuButton      app_menu;
        private Gtk.Box             box;
        private Welcome             welcome;
        private Library             library;
        private Player              player;
        private Gtk.Revealer        revealer;
        private Gtk.Paned           thinpaned;
        private PlaybackBox         playback_box;
        private Gtk.Stack           notebook;
        private Gtk.StackSwitcher   stack_switcher;
        private Sidepane            details;
        private Gtk.Box             headerbar_box;
        private Gtk.Box             import_message_box;
        
        
        /* Headerbar buttons */
        
        private Gtk.Button          play_pause;
        private Gtk.Button          forward;
        private Gtk.Button          backward;
        private Gtk.Button          add_to_library;
        private Gtk.Button          refresh;
        private Gtk.Button          return_to_library;
        private Gtk.Button          download;
        private Gtk.Button 			shownotes_button;
        
        
        /* Secondary widgets */
        
        private AddFeedDialog       add_feed;
        private Gtk.MenuItem        export_item;
        private DownloadsPopover    downloads;
        private ShowNotesPopover    shownotes;
        private Gtk.Popover         add_popover;
        private Gtk.MessageDialog   missing_dialog;
        private SettingsDialog      settings_dialog;
        private VideoControls       video_controls;
        private Gtk.Revealer        return_revealer;
        
        
        /* Icon views and related variables */
        
        private Gtk.FlowBox         all_flowbox;
        private Gtk.FlowBox         audio_flowbox;
        private Gtk.FlowBox         video_flowbox;
        
        private Gtk.ScrolledWindow  all_scrolled;
        private Gtk.ScrolledWindow  audio_scrolled;
        private Gtk.ScrolledWindow  video_scrolled;
            
        
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
        private Gee.ArrayList<CoverArt>      all_art;
        private Gee.ArrayList<CoverArt>      audio_art;
        private Gee.ArrayList<CoverArt>      video_art;
        
        
        /* Miscellaneous global variables */
        
        private string installer;
        private int minutes_elapsed_in_period;
        private uint hiding_timer = 0;
        private bool ignore_window_state_change = false;

		/*
		 * Constructor for the main window. Creates the window and gets everything going.
		 */
        public MainWindow (VocalApp app, bool? open_hidden = false) {
            this.app = app;
            this.set_application (app);

            this.open_hidden = open_hidden;
            if(open_hidden) {
                info("The app will open hidden in the background.");
            }
            
            // Flag this as being newly launched
            this.newly_launched = true;

            // Check whether or not we're running on elementary
            check_elementary();
            
            // Grab the current settings
            this.settings = new VocalSettings();
            
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

            // Create the show notes popover
            shownotes = new ShowNotesPopover(shownotes_button);

            headerbar_box.add(playback_box);
            headerbar_box.add(shownotes_button);

            shownotes_button.clicked.connect(() => {
                shownotes.show_all();
            });  
            
            // Create the Player and Initialize GStreamer
            player = Player.get_default(app.args);
            player.stream_ended.connect(on_stream_ended);
            player.additional_plugins_required.connect(on_additional_plugins_needed);

            
            // Create the drawing area for the video widget
            video_widget = new GtkClutter.Embed();
            video_widget.button_press_event.connect(on_video_button_press_event);

            stage = (Clutter.Stage)video_widget.get_stage ();
            stage.background_color = {0, 0, 0, 0};
            stage.use_alpha = true;

            stage.add_child (player);

            // Set up all the video controls
            video_controls = new VideoControls();
            
            video_controls.vexpand = true;
            video_controls.set_valign (Gtk.Align.END);
            video_controls.unfullscreen.connect(on_fullscreen_request);
            video_controls.play_toggled.connect(play);

            bottom_actor = new GtkClutter.Actor.with_contents (video_controls);
            stage.add_child(bottom_actor);

            video_widget.motion_notify_event.connect(on_motion_event);

            return_to_library = new Gtk.Button.from_icon_name("go-jump-rtl-symbolic", Gtk.IconSize.DIALOG);
            return_to_library.has_tooltip = true;
            return_to_library.tooltip_text = _("Return to library view");
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
            library = new Library();
            
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
            
            // Initialize notifications 
#if HAVE_LIBNOTIFY
            Notify.init("Vocal");
#endif

            // Set up resize requests
            this.check_resize.connect(() => {
                player.configure_video();
            });


            // Connect the new player position available signal from the player
            // to set the new progress on the playback box

            player.new_position_available.connect(() => {
            
                int64 position = player.get_position();
                int64 duration = player.get_duration();
                
                
                // Set the current episode position (will later be saved to database when
                // switching tracks or exiting the program)
                
                if(position > 0) 
                    player.current_episode.last_played_position = position;
            
                double percentage = (double) position / (double) duration;
                
                // Convert nanoseconds to seconds
                position = position / 1000000000;
                duration = duration / 1000000000;
                
                int mins_remaining;
                int secs_remaining;
                int mins_elapsed;
                int secs_elapsed;
                
                mins_elapsed = (int) position / 60;
                secs_elapsed = (int) position % 60;
                
                int64 remaining = duration - position;
                
                mins_remaining = (int) remaining / 60;
                secs_remaining = (int) remaining % 60;

                if(!currently_importing && position != 0) {
                    playback_box.set_progress(percentage, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);  
                    video_controls.set_progress(percentage, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);  
                }
            });

            
            // Set minutes elapsed to zero since the app is just now starting up
            minutes_elapsed_in_period = 0;
            
            // Automatically check for new episodes
            if(settings.update_interval != 0) {
            
                //Increase count and check for match every 5 minutes
                GLib.Timeout.add(300000, () => {

                    minutes_elapsed_in_period += 5;
                    if(minutes_elapsed_in_period == settings.update_interval) {
                    
                        on_update_request();
                        
                    } 
                        
                    return true;
                });
            }
            
            
           
            // Change the player position to match scale changes
            playback_box.scale_changed.connect( () => {
            
                // Get the total duration in nanoseconds
                int64 duration = player.get_duration();      
                
                double val = playback_box.get_progress_bar_fill();
                
                // Multiply percentage by the duration
                
                double position_double = (double) duration * val;
                
                int64 position = (int64) position_double;
                

                // Set the position
                player.set_position (position);
                player.play();
            });

            // Repeat for the video playback box scale
            video_controls.progress_bar_scale_changed.connect( () => {
            
                // Get the total duration in nanoseconds
                int64 duration = player.get_duration();      
                
                double val = video_controls.progress_bar_fill;
                
                // Multiply percentage by the duration
                
                double position_double = (double) duration * val;
                
                int64 position = (int64) position_double;
                

                // Set the position
                player.set_position (position);
                player.play();
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
                            play();
                            break;
                        default:
                            break;
                    }
                });

                mediakeys.GrabMediaPlayerKeys("vocal", 0);
            } catch (Error e) { warning (e.message); }

            
            this.key_press_event.connect ( (e) => {
                

                // Was the control key pressed?
                if((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    switch (e.keyval) {
                        case Gdk.Key.q:
                            this.destroy();
                            break;
                        case Gdk.Key.f:
                            this.on_fullscreen_request();
                            break;
                        default:
                            break;
                    }
                }
                else {
                
                    switch (e.keyval) {
                        case Gdk.Key.p:
                        case Gdk.Key.space:
                            play();
                            break;
                            
                        case Gdk.Key.f:
                        case Gdk.Key.F11:

                            on_fullscreen_request();
                            break;
                        case Gdk.Key.Escape:
                            if(fullscreened)
                                on_fullscreen_request();
                            break;

                        case Gdk.Key.Left:
                            seek_backward();
                            break;
                        case Gdk.Key.Right:
                            seek_forward();
                            break;
                        default:
                            break;
                        }
                }

                return true;
            });

            
            // Build the UI elements
            setup_ui ();
            
            // Show the welcome widget if it's the first run, or if the library is empty
            if(first_run || library_empty) {

        		string add_icon, import_icon;
        		if(on_elementary) {
        			add_icon = "add";
        			import_icon = "document-import";
        		} else {
        			add_icon = "list-add";
        			import_icon = "document-open";
        		}


                 // Create a new Welcome widget
                welcome = new Granite.Widgets.Welcome (_("Welcome to Vocal"), _("Build Your Library By Adding Podcasts"));
                welcome.append(add_icon, _("Add a New Feed"), _("Provide the web address of a podcast feed."));
                // welcome.append("preferences-desktop-online-accounts", _("Browse Podcasts"),
                //     _("Browse through podcasts and choose some to add to your library."));
                welcome.append(import_icon, _("Import Subscriptions"),
                        _("If you have exported feeds from another podcast manager, import them here."));
                welcome.append("vocal", _("Check Out the Vocal Starter Pack…"), _("New to podcasting? Check out our starter pack. Select individual podcasts, or download the entire pack."));

                
                welcome.activated.connect(on_welcome);
                
                box.pack_start (welcome, true, true, 0);
                this.current_widget = welcome;
                
            }
            else {
                setup_library_widgets();
            }
        }
        
        
        /*
         * Set up the UI elements for Vocal
         */
        private void setup_ui () {
            
            box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            
            // Set up the two panes
            thinpaned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
            
            // Create the toolbar
            toolbar = new Gtk.HeaderBar ();
            
            // Create the menus and menuitems
            menu = new Gtk.Menu ();
            
            export_item = new Gtk.MenuItem.with_label(_("Export Subscriptions…"));
            
            // Set refresh and export insensitive if there isn't a library to export
            if(first_run) {
                //refresh_item.sensitive = false;
                export_item.sensitive = false;
            }
            export_item.activate.connect(export_podcasts);
            menu.add(export_item);
            menu.add(new Gtk.SeparatorMenuItem());
            
            
            var preferences_item = new Gtk.MenuItem.with_label(_("Preferences"));
            menu.add(preferences_item);
            
            preferences_item.activate.connect(() => {
                settings_dialog = new SettingsDialog(settings, this);
                settings_dialog.show_all();
            });

            var starterpack = new Gtk.MenuItem.with_label (_("Check Out The Vocal Starter Pack…"));
            starterpack.activate.connect (() => {
                try {
                    GLib.Process.spawn_command_line_async ("xdg-open http://vocalproject.net/starter-pack");
                } catch (Error error) {}
            });
            menu.add(starterpack);
            
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
	    if(on_elementary)
            	app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR)); 
	    else
     		app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
            app_menu.popup = menu;   
            
            if(on_elementary)
                add_to_library = new Gtk.Button.from_icon_name("document-import", Gtk.IconSize.LARGE_TOOLBAR);
            else
                add_to_library = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            add_to_library.has_tooltip = true;
            add_to_library.tooltip_text = _("Add new podcasts to the library");
            
            // Set up the add podcasts popover
            add_popover = new Gtk.Popover(add_to_library);


            var add_button = new Gtk.Button.with_label(_("Add Podcast Feed"));
            add_button.get_style_context().add_class("flat");
            add_button.margin = 5;
            add_button.clicked.connect(() => {
                add_popover.hide();
                add_new_podcast();
            });
            
            var import_button = new Gtk.Button.with_label(_("Import Subscriptions…"));
            import_button.get_style_context().add_class("flat");
            import_button.margin = 5;
            import_button.margin_top = 0;
            import_button.clicked.connect(() => {
                add_popover.hide();
                import_podcasts();
            });
            
            var add_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            add_box.pack_start(add_button, true, true, 0);
            add_box.pack_start(import_button, true, true, 0);
            
            add_popover.add(add_box);
        
            add_to_library.clicked.connect(() => {
                add_popover.show_all();;
            });
            

            // Populate the toolbar
            toolbar.pack_end (app_menu);
            toolbar.pack_end(add_to_library);
            toolbar.set_custom_title(headerbar_box);

            // Initially hide the headearbar_box
            hide_playback_box();

 
            // Add everything to window
            this.add (box);
            this.set_titlebar(toolbar);
            toolbar.show_close_button = true;
        }
        
        
        /*
         * Creates and configures all widgets pertaining the the library view (called either after
         * the user successfully adds content to library for the first time, or at the start of a session
         * that is NOT the first run).
         */
        private void setup_library_widgets() {

            if(current_widget == welcome)
            {
                // Remove the welcome
                box.remove(welcome);
            } else if(current_widget == import_message_box) {
                box.remove(import_message_box);
            }
            
            // Set up scrolled windows so that content will scoll instead of causing the window to expand
            all_scrolled = new Gtk.ScrolledWindow (null, null);
            audio_scrolled = new Gtk.ScrolledWindow (null, null);
            video_scrolled = new Gtk.ScrolledWindow (null, null);           
            
		    // Set up the IconView for all podcasts
		    all_flowbox = new Gtk.FlowBox();
            all_art = new Gee.ArrayList<CoverArt>();
            all_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            all_flowbox.activate_on_single_click = true;
            all_flowbox.child_activated.connect(on_child_activated);

            audio_flowbox = new Gtk.FlowBox();
            audio_art = new Gee.ArrayList<CoverArt>();
            audio_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            audio_flowbox.activate_on_single_click = true;
            audio_flowbox.child_activated.connect(on_child_activated);
     
            video_flowbox = new Gtk.FlowBox();
            video_art = new Gee.ArrayList<CoverArt>();
            video_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            video_flowbox.activate_on_single_click = true;
            video_flowbox.child_activated.connect(on_child_activated);
            
		    all_scrolled.add(all_flowbox);
		    audio_scrolled.add(audio_flowbox);
		    video_scrolled.add(video_flowbox);
             
            notebook = new Gtk.Stack();
            notebook.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            notebook.transition_duration = 300;
            
            notebook.add_titled(all_scrolled, "all", _("All Podcasts"));
            notebook.add_titled(audio_scrolled, "audio", _("Audio"));
            notebook.add_titled(video_scrolled, "video", _("Video"));
            
            stack_switcher = new Gtk.StackSwitcher();
            stack_switcher.set_stack(notebook);
            
            stack_switcher.margin = 5;
            stack_switcher.halign = Gtk.Align.CENTER;
            
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
            forward.tooltip_text = _("Fast forward %d seconds".printf(settings.fast_forward_seconds));
   
            var backward_image = new Gtk.Image.from_icon_name("media-seek-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            backward = new Gtk.Button();
            backward.image = backward_image;
            backward.has_tooltip = true;
            backward.tooltip_text = _("Rewind %d seconds".printf(settings.rewind_seconds));

            // Connect the changed signal for settings to update the tooltips
            settings.changed.connect(() => {
                forward.tooltip_text = _("Fast forward %d seconds".printf(settings.fast_forward_seconds));
                backward.tooltip_text = _("Rewind %d seconds".printf(settings.rewind_seconds));
            });
            
            refresh = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            refresh.has_tooltip = true;
            refresh.tooltip_text = _("Check for new episodes");
        
            refresh.clicked.connect(on_update_request);
            
            //TODO: Add a playback rate button to change speeds
            
            var rate_button = new Gtk.Button.with_label("2x");
            rate_button.clicked.connect(() => {
                player.set_playback_rate(2.0);
            });
            
            
            // Connect signals to appropriate handlers
            
            play_pause.clicked.connect(play);
            forward.clicked.connect(seek_forward);
            backward.clicked.connect(seek_backward);

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
        
            download.clicked.connect(show_downloads_popover);
            download.set_no_show_all(true);
            download.hide();
            downloads = new DownloadsPopover(download);
            downloads.closed.connect(hide_downloads_menuitem);
            downloads.all_downloads_complete.connect(hide_downloads_menuitem);
            
            
            // Add the buttons
            toolbar.pack_start (backward);
	        toolbar.pack_start (play_pause);
	        toolbar.pack_start (forward);
	        toolbar.pack_end (refresh);
	        toolbar.pack_end (download);
	       
	        //toolbar.pack_start(rate_button);
                      
            // Add the thinpaned to the box
            box.pack_start(thinpaned, true, true, 0);
            current_widget = thinpaned;
            
            // Add the notebook
            
            var library_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		    library_box.pack_start(stack_switcher, false, true, 0);
		    library_box.pack_start(notebook, true, true, 0);
		    
		    thinpaned.pack1(library_box, true, false);
		    
		    // Set up the revealer for the side pane
		    revealer = new Gtk.Revealer();
		    revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
            thinpaned.pack2(revealer, true, true);
		    
            // Populate the three IconViews from the library
            populate_views();

            if(!open_hidden)
                show_all();
            else {
                this.iconify();
            }
            
            // Autoclean the library 
            if(settings.autoclean_library)
                library.autoclean_library();
            
            // Check for updates 
            on_update_request();
            
        }
        
        /*
         * Populates the three views (all, audio, video) from the contents of the library
         */
        private void populate_views() {
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

    	            for(int i = 0; i < audio_art.size; i++)
    	            {
    	            	audio_flowbox.remove(audio_flowbox.get_child_at_index(0));
    	            }

    	            for(int i = 0; i < video_art.size; i++)
    	            {
    	            	video_flowbox.remove(video_flowbox.get_child_at_index(0));
    	            }

                    all_art.clear();
                    audio_art.clear();
                    video_art.clear();
                }

	            
	            // If the program was just launched, check to see what the last played media was
	            if(newly_launched) {

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
	                                        playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
	                                        track_changed(current_episode.title, current_episode.parent.name, current_episode.parent.coverart_uri, player.get_duration());

	                                        string new_uri;

	                                        // Determine how long the track is and set the progress bar to match
	                                        if(this.current_episode.local_uri != null) {
	                                            new_uri = """file://""" + this.current_episode.local_uri;
	                                        } else {
	                                            new_uri = this.current_episode.uri;
	                                        }

	                                        bool episode_finished = false;
	                                        try { 

	                                            Gst.PbUtils.Discoverer discoverer = new Gst.PbUtils.Discoverer(5000000000L);
	                                            Gst.PbUtils.DiscovererInfo disc_info = discoverer.discover_uri(new_uri);

	                                            int64 duration = (int64)disc_info.get_duration();
	                                            int64 position = this.current_episode.last_played_position;
	                
	                                            // Convert nanoseconds to seconds
	                                            position = position / 1000000000;
	                                            duration = duration / 1000000000;

	                                            if(position == duration) {
	                                                episode_finished = true;
	                                            }
	                                            
	                                            int mins_remaining;
	                                            int secs_remaining;
	                                            int mins_elapsed;
	                                            int secs_elapsed;

	                                            double percentage = (double) position / (double) duration;
	                                            
	                                            mins_elapsed = (int) position / 60;
	                                            secs_elapsed = (int) position % 60;
	                                            
	                                            int64 remaining = duration - position;
	                                            
	                                            mins_remaining = (int) remaining / 60;
	                                            secs_remaining = (int) remaining % 60;

	                                            playback_box.set_progress(percentage, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);  
	                                            shownotes.set_notes_text(episode.description);

	                                        } catch(Error e) {
	                                            warning(e.message);
	                                        }

	                                        if(current_episode.last_played_position != 0 && !episode_finished) { 
	                                            show_playback_box();
	                                        }
	                                        else {
	                                            hide_playback_box();
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
	            
	            if(library.podcasts.size > 0) {

	                foreach(Podcast podcast in library.podcasts) {
	                
	                    // Determine whether or not there are video podcasts
	                    if(podcast.content_type == MediaType.VIDEO) {
	                        has_video = true;
	                    }

                        CoverArt a = new CoverArt(podcast.coverart_uri.replace("%27", "'"), podcast, true);

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
                        all_flowbox.add(a);

                       
                        
                        // Audio podcast stuff
                        if(podcast.content_type == MediaType.AUDIO) {  
                            CoverArt audio = new CoverArt(podcast.coverart_uri.replace("%27", "'"), podcast);
                            if(currently_unplayed > 0)
                            {
                                audio.set_count(currently_unplayed);
                                audio.show_count();
                            }

                            else
                            {
                                audio.hide_count();
                            }
                            audio_art.add(audio);
                            audio_flowbox.add(audio);
                        }
                        
                        
                        // Video podcast stuff
                        if(podcast.content_type == MediaType.VIDEO) {
                            CoverArt video = new CoverArt(podcast.coverart_uri.replace("%27", "'"), podcast);
                            
                            if(currently_unplayed > 0)
                            {
                                video.set_count(currently_unplayed);
                                video.show_count();
                            }

                            else
                            {
                                video.hide_count();
                            }
                            video_art.add(video);
                            video_flowbox.add(video);
                        }
	                } 
	            } 
	            
	            // Determine whether or not to show the different views/stack switcher
	            
	            if(!has_video) {
	                stack_switcher.set_no_show_all(true);
	                stack_switcher.hide();
	            } else {
	                stack_switcher.set_no_show_all(false);
	                stack_switcher.show();
	            }


	            currently_repopulating = false;
        	}
        }
        
        
        
        /*
         * UI-related methods
         */
         
         
        /*
         * Hides the downloads menuitem if there are no active downloads
         */
        private void hide_downloads_menuitem() {
            if(downloads.downloads.size < 1) {
                download.no_show_all = true;
                download.hide();
                show_all();
            }
        }
			         
        /*
         * Hides the playback box
         */
        private void hide_playback_box() {

            this.headerbar_box.no_show_all = true;
            this.headerbar_box.hide();
        } 
         
        /*
         * Called when a podcast is selected from an iconview. Creates and displays a new window containing
         * the podcast and episode information
         */
        private void show_details (Podcast current_podcast) {
            
            
            // Remove the previous sidebar if there is one
            if(details != null) {

                int new_width = thinpaned.max_position - thinpaned.position;

                // There is a possibility that the sidebar was hidden, so only set it large enough
                if(new_width >= 100)
                    settings.sidebar_width = thinpaned.max_position - thinpaned.position;    

                revealer.reveal_child = false;
                revealer.remove(details);
            }
            
            details = new Sidepane(this, current_podcast, on_elementary);
            
            // Set up all the signals for the new side pane
            details.play_episode_requested.connect(play_different_track);
            details.download_episode_requested.connect(download_episode);
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

            details.pane_should_hide.connect(() => {
                revealer.reveal_child = false;
                thinpaned.position = -1;
            });
            
            // Set up a revealer for the sidebar
            
            revealer.add(details);
            show_all();
            revealer.reveal_child = true;
            thinpaned.position = thinpaned.max_position - settings.sidebar_width;
        }
        
        /*
         * Shows the downloads popover
         */
        private void show_downloads_popover() {
            this.downloads.show_all();
        }
        
     	/*
         * Shows the playback box
         */
        private void show_playback_box() {

            this.headerbar_box.no_show_all = false;
            this.headerbar_box.show();
            show_all();
        }


        /*
         * Playback functions
         */
         
         
        /*
         * Handles play requests and starts media playback using the player
         */
        public void play() {
            
            if(current_episode != null) {
                show_playback_box();
                
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
                    player.set_state(Gst.State.READY);
                    
                }
               
                
                // Are we playing a video? If so, is the video widget already being displayed?
                if(player.current_episode.parent.content_type == MediaType.VIDEO && current_widget != video_widget) {               
                     
                    // Remove the library view if necessary
                    box.remove(thinpaned);
                    box.pack_start(video_widget, true, true, 0);
                    current_widget = video_widget;

                    // Re-configure the video
                    player.configure_video();  
   
                }
                
                if(player.is_currently_playing) {
                    player.pause();
                    playback_status_changed("Paused");
                    var playpause_image = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                    play_pause.image = playpause_image;
                    play_pause.tooltip_text = _("Play");

                    var video_playpause_image = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                    video_controls.play_button.image = video_playpause_image;
                    video_controls.tooltip_text = _("Play");

                    // Set last played position
                    current_episode.last_played_position = player.get_position();
                    library.set_episode_playback_position(player.current_episode);
                }
                else {                

                    player.play();
                    playback_status_changed("Playing");

                    // Seek if necessary
                    if(current_episode.last_played_position > 0 && current_episode.last_played_position > player.get_position()) {

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
                    play_pause.image = playpause_image;
                    play_pause.tooltip_text = _("Pause");

                    var video_playpause_image = new Gtk.Image.from_icon_name("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                    video_controls.play_button.image = video_playpause_image;
                    video_controls.tooltip_text = _("Pause");
                    
                }

                if(!currently_importing) {
                    playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                    video_controls.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                    shownotes.set_notes_text(current_episode.description);
                }
                show_all();    
            }


        }
        
        /*
         * Switches the current track and requests the newly selected track starts playing
         */
        private void play_different_track () {

            // Get the episode            
            int index = details.current_episode_index;
            current_episode = details.podcast.episodes[index];
            
            // Set episode position and start playback
            player.set_state(Gst.State.READY);

            play();

            // Set the shownotes, the media information, and update the last played media in the settings     
            track_changed(current_episode.title, current_episode.parent.name, current_episode.parent.coverart_uri, player.get_duration());
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
         * Attempts to check whether or not Vocal is running on elementary OS
         */
        private void check_elementary() {
            string output;
            output = GLib.Environment.get_variable("XDG_CURRENT_DESKTOP");

            if (output != null && output.contains ("Pantheon")) {  
                on_elementary = true;
            }
         }
         
        /*
         * Handles request to download an episode, by showing the downloads menuitem and 
         * requesting the download from the library
         */
        private void download_episode(Episode episode) {
            
            // Show the download menuitem
            this.download.set_no_show_all(false);
            this.download.show_all();
            
            
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

                show_playback_box();

                // Hide the shownotes button
                shownotes_button.set_no_show_all(true);
                shownotes_button.hide();
            
                var loop = new MainLoop();
                library.add_from_OPML(file_name, (obj, res) => {

                    bool success = library.add_from_OPML.end(res);

                    if(success) {
                                       
                        if(!player.is_currently_playing)
                            hide_playback_box();
                            
                        // Is there now at least one podcast in the library?
                        if(library.podcasts.size > 0) {

                            // Make the refresh and export items sensitive now
                            //refresh_item.sensitive = true;
                            export_item.sensitive = true;

                            // Hide the shownotes button
                            shownotes_button.set_no_show_all(false);
                            shownotes_button.show();
                        
                            // Set up the initial widgets
                            if(first_run || library_empty) {

                                // The library widgets (play/pause, next, forward, iconviews, etc.)
                                setup_library_widgets();

                                // Although setup_library_widgets calls populate_views, an additional call is necessary when adding the first feed ever
                                populate_views();
                            } else {
                                // but if we don't setup widgets, we need to repopulate the views
                                populate_views();
                            }

                            library_empty = false;
                            
                            show_all();
                        }


                    } else {

                        if(!player.is_currently_playing)
                            hide_playback_box();
                       
                        var add_err_dialog = new Gtk.MessageDialog(add_feed,
                            Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,
                            Gtk.ButtonsType.OK, "");
                            add_err_dialog.response.connect((response_id) => {
                                add_err_dialog.destroy();
                            });
                                
                        var error_img = new Gtk.Image.from_icon_name ("dialog-error", Gtk.IconSize.DIALOG);
                        add_err_dialog.set_transient_for(this);
                        add_err_dialog.text = _("Error Importing from File");
                        add_err_dialog.secondary_text = _("Please check that you selected the correct file and that you are connected to the network.");
                        add_err_dialog.set_image(error_img);
                        add_err_dialog.show_all();
                    }

                    currently_importing = false;

                    if(player.is_currently_playing) {
                        playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                        video_controls.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                    }
                    
                    loop.quit();
                });
                loop.run();
                
                file_chooser.destroy();
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
                            player.set_state(Gst.State.NULL);
                            player.set_state(Gst.State.READY);
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

            currently_importing = true;

            if(response_id == Gtk.ResponseType.OK) {
                if(add_feed != null) {
                    string entered_feed = add_feed.entry.get_text();
                    add_feed.destroy();
                    
                    // Hide the shownotes button
                    shownotes_button.set_no_show_all(true);
                    shownotes_button.hide();
                    
                    playback_box.set_message(_("Adding new podcast: <b>" + entered_feed + "</b>"));
                    show_playback_box();
                    
                    var loop = new MainLoop();
                    bool success = false;

                    library.async_add_podcast_from_file(entered_feed, (obj, res) => {
                        success = library.async_add_podcast_from_file.end(res);
                        currently_importing = false;
                        if(player.is_currently_playing) {
                            playback_box.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                            video_controls.set_info_title(current_episode.title.replace("%27", "'"), current_episode.parent.name.replace("%27", "'"));
                        }
                        loop.quit(); 
                    });

                    loop.run();


                    if(success) {
                        if(!player.is_currently_playing)
                            hide_playback_box();
                            
                        // Is there now at least one podcast in the library?
                        if(library.podcasts.size > 0) {

                            // Make the refresh and export items sensitive now
                            //refresh_item.sensitive = true;
                            export_item.sensitive = true;

                            // Hide the shownotes button
                            shownotes_button.set_no_show_all(false);
                            shownotes_button.show();
                        
                            // Set up the initial widgets
                            if(first_run || library_empty) {

                                // The library widgets (play/pause, next, forward, iconviews, etc.)
                                setup_library_widgets();

                                // Although setup_library_widgets calls populate_views, an additional call is necessary when adding the first feed ever
                                populate_views();
                            } else {
                                // but if we don't setup widgets, we need to repopulate the views
                                populate_views();
                            }

                            library_empty = false;
                            
                            show_all();
                        }  
                    } else {

                        if(!player.is_currently_playing)
                            hide_playback_box();

                        var add_err_dialog = new Gtk.MessageDialog(add_feed,
                        Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,
                        Gtk.ButtonsType.OK, "");
                        add_err_dialog.response.connect((response_id) => {
                            add_err_dialog.destroy();
                        });
                
                        var error_img = new Gtk.Image.from_icon_name ("dialog-error", Gtk.IconSize.DIALOG);
                        add_err_dialog.set_transient_for(this);
                        add_err_dialog.text = _("Error Adding Podcast");
                        add_err_dialog.secondary_text = _("Please check that the feed is correct and that you have a network connection.");
                        add_err_dialog.set_image(error_img);
                        add_err_dialog.show_all();
                    }
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
        private void on_child_activated(FlowBoxChild child)
        {
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
                int index = details.get_box_index_from_episode(episode);

                // Set the box to hide the downloads button
                if(index != -1) {
                    details.boxes[index].hide_download_button();
                    details.boxes[index].show_playback_button();
                }
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
        
            this.playback_box.set_message_and_percentage("Adding feed %d/%d: %s".printf(current, total, title), (double)((double)current/(double)total));

            if(first_run && current_widget != import_message_box)
            {
                box.remove(welcome);
                import_message_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 25);
                var import_h1_label = new Gtk.Label(_("Good Stuff is On Its Way"));
                var import_h3_label = new Gtk.Label(_("If you are importing several podcasts it can take a few minutes. Your library will be ready shortly.")); 
                Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H1, import_h1_label);
                Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H3, import_h3_label);
                import_h1_label.margin_top = 200;
                import_message_box.add(import_h1_label);
                import_message_box.add(import_h3_label);
                box.add(import_message_box);
                current_widget = import_message_box;

                show_all();
            }
            
        }
        
        /*
         * Called when the user requests to mark a podcast as played from the library via the right-click menu
         */
        private void on_mark_as_played_request() {
        
            if(highlighted_podcast != null) {
                Gtk.MessageDialog msg = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO,
                     "Are you sure you want to mark all episodes from '%s' as played?".printf(highlighted_podcast.name.replace("%27", "'")));
                     
                var image = new Gtk.Image.from_icon_name("dialog-question", Gtk.IconSize.DIALOG);     
                msg.image = image;
                msg.image.show_all();
                
			    msg.response.connect ((response_id) => {
			        switch (response_id) {
				        case Gtk.ResponseType.YES:
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
                            if(highlighted_podcast.content_type == MediaType.AUDIO) {
                                foreach(CoverArt audio in all_art)
                                {
                                    if(audio.podcast == highlighted_podcast)
                                    {
                                        audio.set_count(0);
                                        audio.hide_count();
                                    }
                                }
                            }
                            else {
                                foreach(CoverArt video in all_art)
                                {
                                    if(video.podcast == highlighted_podcast)
                                    {
                                        video.set_count(0);
                                        video.hide_count();
                                    }
                                }
                            }

                            details.mark_all_played();

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

            // Show the cursor again
            this.get_window ().set_cursor (null);

            bool hovering_over_return_button = false, hovering_over_video_controls = false;
            int min_height, natural_height;
            video_controls.get_preferred_height(out min_height, out natural_height);

            if (fullscreened && e.y < natural_height) {
                hovering_over_video_controls = true;
            } else {
                hovering_over_video_controls = false;
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

                    this.get_window ().set_cursor (new Gdk.Cursor (Gdk.CursorType.BLANK_CURSOR));

                    return false;
                });
            

                if(fullscreened) {
                    bottom_actor.width = stage.width;
                    bottom_actor.y = stage.height - natural_height;
                    video_controls.set_reveal_child(true);
                }
                return_revealer.set_reveal_child(true);

            }   

            return false;
        }

        
        /*
         * Called when the user requests to remove a podcast from the library via the right-click menu
         */
        private void on_remove_request() {
            if(highlighted_podcast != null) {
                Gtk.MessageDialog msg = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE,
                     "Are you sure you want to remove '%s' from your library?".printf(highlighted_podcast.name.replace("%27", "'")));
                     
                     
                msg.add_button ("_No", Gtk.ResponseType.NO);
                Gtk.Button delete_button = (Gtk.Button) msg.add_button("_Yes", Gtk.ResponseType.YES);
                delete_button.get_style_context().add_class("destructive-action");
                     
                var image = new Gtk.Image.from_icon_name("dialog-warning", Gtk.IconSize.DIALOG);     
                msg.image = image;
                msg.image.show_all();
                
			    msg.response.connect ((response_id) => {
			        switch (response_id) {
				        case Gtk.ResponseType.YES:
					        library.remove_podcast(highlighted_podcast);
					        populate_views();
					        highlighted_podcast = null;
                            details.pane_should_hide();
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
            if(player.is_currently_playing)
                play();

            if (hiding_timer != 0) {
                Source.remove (hiding_timer);
            }

            // Wait just a short while before returning to library
            GLib.Timeout.add(1000, () => {

                // Remove the video widget
                box.remove(video_widget);
                
                // Add the thinpaned back
    		    box.pack_start(thinpaned);

                current_widget = thinpaned;

                // Make sure the cursor is visible again
                this.get_window ().set_cursor (null);

                return false;
            });
        }
        
        /*
         * Called when the player finishes a stream
         */
        private void on_stream_ended() {
        
            // hide the playback box and set the image on the pause button to play
            hide_playback_box();
            
            var playpause_image = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            play_pause.image = playpause_image;



            // If there is a video showing, return to the library view
            if(current_episode.parent.content_type == MediaType.VIDEO && current_widget != thinpaned) {
                on_return_to_library();
            }


            // Reset the last played position and save it 
            player.set_state(Gst.State.NULL);
            player.current_episode.last_played_position = 0;
            library.set_episode_playback_position(player.current_episode);

            playback_status_changed("Stopped");
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
         * Check for new episodes
         */
        private void on_update_request() {
               
            // Only check for updates if no other checks are currently under way
            if(!checking_for_updates) {
            
                checking_for_updates = true;
        
                // Create an arraylist to store new episodes
                Gee.ArrayList<Episode> new_episodes = new Gee.ArrayList<Episode>();
                             
                // Check for new updates
                debug("Checking for updates");

                
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
                
                debug("Update complete");
                
                checking_for_updates = false;

                

                // Send a notification if there are new episodes
                if(new_episodes.size > 0)
                {
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
            if(e.type == Gdk.EventType.2BUTTON_PRESS) {
                on_fullscreen_request();
            }

            return false;

        }
        
        /*
         * Handles responses from the welcome screen
         */
        private void on_welcome(int index) {
        
            // Add a new feed
            if (index == 0 ) {
                add_feed = new AddFeedDialog(this, on_elementary);
                add_feed.response.connect(on_add_podcast_feed);
                add_feed.show_all();

            // Import from OPML
            } else if (index == 1) {

                // The import podcasts method will handle any errors
                import_podcasts();

            // Starter pack
            } else {

                try {
                    GLib.Process.spawn_command_line_async ("xdg-open http://vocalproject.net/starter-pack");
                } catch (Error error) {}
            }

        }
        
        
        /*
         * Saves the window height and width before closing, and decides whether to close or minimize
         * based on whether or not a track is currently playing
         */
        private bool on_window_closing() {

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

            if(details != null) {
                int new_width = thinpaned.max_position - thinpaned.position;

                // There is a possibility that the sidebar was hidden, so only set it large enough
                if(new_width >= 100)
                    settings.sidebar_width = thinpaned.max_position - thinpaned.position;       
            }


            
            // Save the playback position
            if(player.current_episode != null) {
                stdout.printf("Setting the last played position to %s\n", player.current_episode.last_played_position.to_string());
                if(player.current_episode.last_played_position != 0)
                    library.set_episode_playback_position(player.current_episode);
            }
              
            // If an episode is currently playing just minimize the window
            if(player.is_currently_playing) {
                this.iconify();
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
