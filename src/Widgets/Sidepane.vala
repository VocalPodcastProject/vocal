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
    class Sidepane : Gtk.Box {
    
    	/* Signals */
    
    	public signal void play_episode_requested();
    	public signal void download_episode_requested(Episode episode);
        public signal void delete_local_episode_requested(Episode episode);
        public signal void delete_multiple_episodes_requested(Gee.ArrayList<int> indexes);
        public signal void mark_all_episodes_as_played_requested();
        public signal void mark_episode_as_played_requested(Episode episode);
        public signal void mark_multiple_episodes_as_played_requested(Gee.ArrayList<int> indexes);
        public signal void mark_episode_as_unplayed_requested(Episode episode);
        public signal void mark_multiple_episodes_as_unplayed_requested(Gee.ArrayList<int> indexes);
    	public signal void pane_should_hide();
        public signal void download_all_requested();
        public signal void delete_podcast_requested();
        public signal void unplayed_count_changed(int n);

    
        public Podcast 			podcast;				// The parent podcast
        public MainWindow 		parent;					// The parent window
        private VocalSettings 	settings;				// Vocal's current settings
        public int 				current_episode_index;  // The index of the episode currently being used
        private int 			boxes_index;        	// Refers to an index in the list of boxes
        
        private Gtk.ListBox listbox;
        private Gtk.Toolbar toolbar;
        private Gtk.Box toolbar_box;
        private Gtk.Label count_label;
        private string count_string;

        private Gtk.Menu right_click_menu;
		
		public Gee.ArrayList<EpisodeDetailBox> boxes;
		private EpisodeDetailBox previously_selected_box;
        private EpisodeDetailBox previously_activated_box;
		private Gtk.ScrolledWindow scrolled;
		private int largest_box_size;
		public int  unplayed_count;
		private int limit;

		/*
		 * Constructor for a Sidepane given a parent window and pocast
		 */
        public Sidepane (MainWindow parent, Podcast podcast, bool? on_elementary = true) {
            assert(podcast!= null);
            this.podcast = podcast;
            this.parent = parent;
            this.settings = new VocalSettings();
            
            largest_box_size = 500;
            
			this.current_episode_index = 0;
            this.boxes_index = 0;
			this.orientation = Gtk.Orientation.VERTICAL;
			
			count_string = null;
			
            toolbar = new Gtk.Toolbar();
            toolbar.icon_size = Gtk.IconSize.MENU;


            var mark_as_played_image = new Gtk.Image.from_icon_name("object-select-symbolic", Gtk.IconSize.MENU);
            Gtk.ToolButton mark_as_played = new Gtk.ToolButton(mark_as_played_image, null);
            mark_as_played.tooltip_text = _("Mark all episodes as played");
            mark_as_played.clicked.connect(() => {
                mark_all_episodes_as_played_requested();
            });
            toolbar.insert(mark_as_played, 0);

	    Gtk.Image download_image;	
	    if(on_elementary)
            	download_image = new Gtk.Image.from_icon_name("browser-download-symbolic", Gtk.IconSize.MENU);
	    else
		download_image = new Gtk.Image.from_icon_name("document-save-symbolic", Gtk.IconSize.MENU);
            Gtk.ToolButton download_all = new Gtk.ToolButton(download_image, null);
            download_all.tooltip_text = _("Download all episodes");
            download_all.clicked.connect(() => {
                download_all_requested();
            });  
            toolbar.insert(download_all, 1);

            var hide_played_image = new Gtk.Image.from_icon_name("view-list-symbolic", Gtk.IconSize.MENU);
            Gtk.ToolButton hide_played = new Gtk.ToolButton(hide_played_image, null);
            hide_played.tooltip_text = _("Hide episodes that have already been played");
            hide_played.clicked.connect(() => {

                if(settings.hide_played) {
                    settings.hide_played = false;
                } else {
                    settings.hide_played = true;
                }

                populate_episodes();
                show_all();
            });

            toolbar.insert(hide_played, 2);

            Gtk.ToolItem spacer = new Gtk.ToolItem();
            spacer.set_expand(true);
            toolbar.insert(spacer, 3);

            var more_menu = new Gtk.Menu ();
            var remove = new Gtk.MenuItem.with_label (_("Remove podcast from library"));
            remove.activate.connect (() => {
               delete_podcast_requested();
            });
            remove.set_no_show_all(false);
            remove.show();
            more_menu.add(remove);


            var menu_image = new Gtk.Image.from_icon_name("open-menu-symbolic", Gtk.IconSize.MENU);
            Gtk.ToolButton menu = new Gtk.ToolButton(menu_image, null);
            menu.tooltip_text = _("More options");

            menu.clicked.connect(() => {
                more_menu.popup(null, null, null, 1,Gdk.CURRENT_TIME );
            });


            toolbar.insert(menu, 4);

            toolbar_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            toolbar_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), true, true, 0);
            toolbar_box.pack_start(toolbar, true, true, 0);



			// Create the header box and set it up
			var headerbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
			var horizontal_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
			var labelbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
			labelbox.hexpand = true;
				
			try {
			    GLib.File cover = GLib.File.new_for_uri(podcast.coverart_uri);
                InputStream input_stream = cover.read();
                var pixbuf = new Gdk.Pixbuf.from_stream_at_scale(input_stream, 64, 64, true);
                var image = new Gtk.Image.from_pixbuf(pixbuf);
                image.margin = 5;
                image.margin_bottom = 0;

                horizontal_box.pack_start(image, false, false, 0);
            } catch (Error e) {}
            
            
			var name_label = new Gtk.Label(podcast.name.replace("%27", "'"));
			count_label = new Gtk.Label(count_string);
			name_label.max_width_chars = 15;
			name_label.wrap = true;
			name_label.justify = Gtk.Justification.CENTER;
			
			Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H2, name_label);
            Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H3, count_label);
            
            
			labelbox.pack_start(name_label, true, true, 0);
			labelbox.pack_start(count_label, true, true, 0);
			horizontal_box.pack_start(labelbox, true, true, 0);
			
			// Set up the hide panel button
             Gtk.Button hide_pane;
            if(parent.on_elementary)
			     hide_pane = new Gtk.Button.from_icon_name("pane-hide-symbolic", Gtk.IconSize.BUTTON);
            else
                hide_pane = new Gtk.Button.from_icon_name("go-last-symbolic", Gtk.IconSize.BUTTON);
			hide_pane.relief = Gtk.ReliefStyle.NONE;
            hide_pane.tooltip_text = _("Hide the episode side pane");
			hide_pane.clicked.connect(() => {
			    pane_should_hide();
			});
			horizontal_box.pack_start(hide_pane, false, false, 0);
			
			headerbox.pack_start(horizontal_box, false, false, 0);
            headerbox.add(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));
			
			this.add(headerbox);

            // Populate the list box
            populate_episodes();          
              
        }
        
        /* 
         * Gets an episode's corresponding box index in the list of EpisodeDetailBoxes
         */
        public int get_box_index_from_episode(Episode e) {

            int index = 0;
            foreach(EpisodeDetailBox b in boxes) {
                if(b.episode == e) {
                    return index;
                } else {
                    index++;
                }
            }

            return -1;
        }
        
        /*
         * Marks each episode detail box in the list as played
         */
        public void mark_all_played() {
            foreach(EpisodeDetailBox b in boxes) {
                b.mark_as_played();
            }
        }

		/*
		 * Handler for when a box has a button press event
		 */
        private bool on_button_press_event(Gdk.EventButton e) {

            if(e.button == 3 && podcast.episodes.size > 0) {

                GLib.List<weak ListBoxRow> rows = listbox.get_selected_rows();
                if(rows.length() > 1) {


                    // Multiple rows selected

                    right_click_menu = new Gtk.Menu();
             
                    var mark_played_menuitem = new Gtk.MenuItem.with_label(_("Mark selected episodes as played"));

                    mark_played_menuitem.activate.connect(() => {

                            GLib.List<weak ListBoxRow> rows1 = listbox.get_selected_rows();
                            Gee.ArrayList<int> indexes = new Gee.ArrayList<int>();


                            foreach(ListBoxRow r in rows1) {
                                current_episode_index = (podcast.episodes.size - r.get_index() - 1);
                                indexes.add(current_episode_index);
                            }


                            // Set all the boxes to hide the played image
                            foreach(int i in indexes) {
                                int floor = podcast.episodes.size - limit -1;
                                int num;

                                (floor >= 0) ? num = i - floor : num = i;

                                boxes[num].mark_as_played();
                            }

                            mark_multiple_episodes_as_played_requested(indexes);
                            reset_unplayed_count();

                    });
                    right_click_menu.add(mark_played_menuitem);

                    var mark_unplayed_menuitem = new Gtk.MenuItem.with_label(_("Mark selected episodes as unplayed"));
                    mark_unplayed_menuitem.activate.connect(() => {

                        GLib.List<weak ListBoxRow> rows2 = listbox.get_selected_rows();
                        Gee.ArrayList<int> indexes = new Gee.ArrayList<int>();

                        foreach(ListBoxRow r in rows2) {
                            current_episode_index = (podcast.episodes.size - r.get_index() - 1);
                            indexes.add(current_episode_index);
                        }

                        

                        // Set all the boxes to show the played image
                        foreach(int i in indexes) {
                            int floor = podcast.episodes.size - limit -1;
                            int num;

                            (floor >= 0) ? num = i - floor : num = i;
       
                            boxes[num].mark_as_unplayed();
                        }

                        mark_multiple_episodes_as_unplayed_requested(indexes);  

                        reset_unplayed_count();


                    });
                    right_click_menu.add(mark_unplayed_menuitem);


                    var delete_menuitem = new Gtk.MenuItem.with_label(_("Delete local files for selected episodes"));
                    delete_menuitem.activate.connect(() => {

                        Gtk.MessageDialog msg = new Gtk.MessageDialog (parent, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE,
                             _("Are you sure you want to delete the downloaded files for the selected episodes?"));
                             
                             
                        msg.add_button ("_No", Gtk.ResponseType.CANCEL);
                        Gtk.Button delete_button = (Gtk.Button) msg.add_button("_Yes", Gtk.ResponseType.YES);
                        delete_button.get_style_context().add_class("destructive-action");
                    
                        var image = new Gtk.Image.from_icon_name("dialog-question", Gtk.IconSize.DIALOG);     
                        msg.image = image;
                        msg.image.show_all();
                        
                        msg.response.connect ((response_id) => {
                            switch (response_id) {
                                case Gtk.ResponseType.YES:

                                    GLib.List<weak ListBoxRow> rows3 = listbox.get_selected_rows();
                                    Gee.ArrayList<int> indexes = new Gee.ArrayList<int>();


                                    foreach(ListBoxRow r in rows3) {
                                        current_episode_index = (podcast.episodes.size - r.get_index() - 1);
                                        indexes.add(current_episode_index);
                                    }

                                    delete_multiple_episodes_requested(indexes);
                                    break;
                                case Gtk.ResponseType.NO:
                                    break;
                            }
                            msg.destroy();
                        });

                        msg.show ();

                    });
                    right_click_menu.add(delete_menuitem);



                } else {

                    // Only a single row selected

                    ListBoxRow new_row = listbox.get_row_at_y((int)e.y);
                    current_episode_index = (podcast.episodes.size - new_row.get_index() - 1);
                    
                    if(current_episode_index >= 0 && current_episode_index < boxes.size) {
                        previously_selected_box = boxes[current_episode_index];
                    }

                    // Populate the right click menu based on the current conditions
                    right_click_menu = new Gtk.Menu();

                    // Mark as played
                    if(podcast.episodes[current_episode_index].status != EpisodeStatus.PLAYED) {
                        var mark_played_menuitem = new Gtk.MenuItem.with_label(_("Mark as Played"));
                        mark_played_menuitem.activate.connect(() => {
                            unplayed_count--;
                            set_unplayed_text();

                            // Remove the unplayed image from the episode's box
                            int floor = podcast.episodes.size - limit -1;
                            int num;

                            (floor >= 0) ? num = current_episode_index - floor : num = current_episode_index;
       
                            boxes[num].mark_as_played();

                            mark_episode_as_played_requested(podcast.episodes[current_episode_index]);
                        });
                        right_click_menu.add(mark_played_menuitem);

                    // Mark as unplayed
                    } else {
                        var mark_unplayed_menuitem = new Gtk.MenuItem.with_label(_("Mark as Unplayed"));
                        mark_unplayed_menuitem.activate.connect(() => {
                            unplayed_count++;
                            set_unplayed_text();

                            // Remove the unplayed image from the episode's box
                            int floor = podcast.episodes.size - limit -1;
                            int num;

                            (floor >= 0) ? num = current_episode_index - floor : num = current_episode_index;
       
                            boxes[num].mark_as_unplayed();

                            mark_episode_as_unplayed_requested(podcast.episodes[current_episode_index]);
                        });
                        right_click_menu.add(mark_unplayed_menuitem);
                    }

                    if(podcast.episodes[current_episode_index].current_download_status == DownloadStatus.DOWNLOADED) {

                        var delete_menuitem = new Gtk.MenuItem.with_label(_("Delete Local File"));

                        delete_menuitem.activate.connect(() => {
                            Gtk.MessageDialog msg = new Gtk.MessageDialog (parent, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE,
                                 "Are you sure you want to delete the downloaded episode '%s'?".printf(podcast.episodes[current_episode_index].title.replace("%27", "'")));
                                 
                                 
                            msg.add_button ("_No", Gtk.ResponseType.CANCEL);
                            Gtk.Button delete_button = (Gtk.Button) msg.add_button("_Yes", Gtk.ResponseType.YES);
                            delete_button.get_style_context().add_class("destructive-action");
                        
                            var image = new Gtk.Image.from_icon_name("dialog-question", Gtk.IconSize.DIALOG);     
                            msg.image = image;
                            msg.image.show_all();
                            
                            msg.response.connect ((response_id) => {
                                switch (response_id) {
                                    case Gtk.ResponseType.YES:
                                        delete_local_episode_requested(podcast.episodes[current_episode_index]);
                                        break;
                                    case Gtk.ResponseType.NO:
                                        break;
                                }

                                msg.destroy();
                            });
                            msg.show ();
                                        
                        });

                        right_click_menu.add(delete_menuitem);
                    }
                }

                right_click_menu.show_all();
                right_click_menu.popup(null, null, null, e.button, e.time);
            }

            return false;
        }

        /*
         * When a row is activated, clear the unplayed icon if there is one and request
         * the corresponding episode be played
         */
        private void on_row_activated(ListBoxRow? row) {

            if(previously_activated_box != null) {
                previously_activated_box.clear_now_playing();
            }
            if(boxes_index >= 0 && boxes_index < boxes.size) {
                previously_activated_box = boxes[boxes_index];
            }
        
            
            // Clear the unplayed icon
            if(podcast.episodes[current_episode_index].status == EpisodeStatus.UNPLAYED) {

                // Mark the box as played
                previously_activated_box.mark_as_played();

                // Set the new unplayed count in the top area
                unplayed_count--;
                set_unplayed_text();

                // Re-mark the box so it doesn't show if hide played is enabled
                if(settings.hide_played && unplayed_count > 0) {
                    previously_activated_box.set_no_show_all(true);
                    previously_activated_box.hide();
                } 
            }
            

            // No matter what, mark this box as now playing
            previously_activated_box.mark_as_now_playing();
            show_all();

            play_episode_requested();
        }
        
        
        /*
         * When a row is selected, highlight it and show the details
         */
        private void on_row_selected() {

            GLib.List<weak ListBoxRow> rows = listbox.get_selected_rows();
            if(rows.length() > 1)
                return;
            

            ListBoxRow new_row = listbox.get_selected_row();
            current_episode_index = (podcast.episodes.size - new_row.get_index() - 1);
            boxes_index = boxes.size - new_row.get_index() - 1;
            
            if(current_episode_index >= 0 && current_episode_index < boxes.size) {
                previously_selected_box = boxes[current_episode_index];
            }           
        }
        
        /*
         * Handler for when a single episode needs to be marked as remote (needs downloading)
         */
        public void on_single_delete(Episode e) {
            int index = get_box_index_from_episode(e);
            if(index != -1) {
                boxes[index].show_playback_button();
                boxes[index].show_download_button();
            }
        }

        /*
         * When a streaming button gets clicked set the current episode and treat
         * it like a row has been activated
         */
        private void on_streaming_button_clicked(int index, int box_index) {

            current_episode_index = index;
            boxes_index = box_index;
            on_row_activated(null);  
        }
        
        /*
         * Creates an EpisodeDetailBox for each episode and adds it to the window
         */
        public void populate_episodes(int? limit = 25) {

        	this.limit = limit;

        	// The count is used for finding the right episodes in the exact right order
        	int count = (limit < podcast.episodes.size) ? limit : (podcast.episodes.size - 1);
        	
            
            var children = this.get_children();
            if(children.index(toolbar_box) > 0) {
                remove(toolbar_box);
                remove(scrolled);
            }

            scrolled = new Gtk.ScrolledWindow (null, null);
            listbox = new Gtk.ListBox();
            listbox.activate_on_single_click = false;
            listbox.selection_mode = Gtk.SelectionMode.MULTIPLE;
            listbox.expand = true;


            // If there are episodes, create an episode detail box for each of them

            if(this.podcast.episodes.size > 0) {
            
                boxes = new Gee.ArrayList<EpisodeDetailBox>();
                listbox.row_selected.connect(on_row_selected);
                listbox.row_activated.connect(on_row_activated);
                
                unplayed_count = 0;
                int i = 0;		// An index for the episodes array

                while (count >= 0 && ((podcast.episodes.size - 1) - count) >= 0) {
                	Episode current_episode = podcast.episodes[(podcast.episodes.size - 1) - count];
                    EpisodeDetailBox current_episode_box = new EpisodeDetailBox(current_episode, ((podcast.episodes.size - 1) - count), boxes.size, parent.on_elementary);
                    current_episode_box.streaming_button_clicked.connect(on_streaming_button_clicked);
                    if(current_episode_box.top_box_width > this.largest_box_size) {
                        this.largest_box_size = current_episode_box.top_box_width;
                    }
                    current_episode_box.download_button.clicked.connect(() => {
                        current_episode_box.hide_download_button();
                        download_episode_requested(current_episode);
                    });


                    boxes.add(current_episode_box);
                    listbox.prepend(current_episode_box);                    
                    
                    // Determine whether or not the episode has been played
                    if(current_episode.status == EpisodeStatus.UNPLAYED) {
                        unplayed_count++;
                    } else if(current_episode == parent.current_episode) {
                        current_episode_box.mark_as_now_playing();
                        if(settings.hide_played) {
                            current_episode_box.set_no_show_all(true);
                            current_episode_box.hide();
                        }
                    } else {
                        if(settings.hide_played) {
                            current_episode_box.set_no_show_all(true);
                            current_episode_box.hide();
                        }
                    }
                    i++;
                    count--;
                }

                // Check to see if there are more episodes left
                if(this.limit < podcast.episodes.size && !settings.hide_played)
                {

                	// If so, add a button that will increase the limit
                	var increase_button = new Gtk.Button.with_label("Show more episodes");
                	increase_button.clicked.connect(() => {
                		populate_episodes(this.limit += 25);
                		this.show_all();
            		});

            		listbox.insert(increase_button, -1);
                }

                if(settings.hide_played && unplayed_count == 0) {
                    var no_new_label = new Gtk.Label(_("No new episodes."));
                    no_new_label.margin_top = 25;
                    Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H3, no_new_label);
                    listbox.prepend(no_new_label);
                }


            // Otherwise, simply create a new label to tell user that the feed is empty    
            } else {
                var empty_label = new Gtk.Label(_("No episodes available."));
                empty_label.justify = Gtk.Justification.CENTER;
                empty_label.margin = 10;
            
                Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H3, empty_label);
                listbox.prepend(empty_label);
            }

            listbox.button_press_event.connect(on_button_press_event);

            scrolled.add(listbox);

            add(scrolled);
            add(toolbar_box);
            set_unplayed_text();
        }
        
        /*
         * Resets the unplayed count and iterates through the boxes to obtain a new one
         */
        public void reset_unplayed_count() {

            int previous_count = unplayed_count;

            unplayed_count = 0;

            foreach(Episode e in podcast.episodes) {
                if(e.status == EpisodeStatus.UNPLAYED)
                    unplayed_count++;
            }

            set_unplayed_text();

            // Is the number of unplayed episodes now different?
            if(previous_count != unplayed_count)
                unplayed_count_changed(unplayed_count);
        }

		/*
 		 * Sets the unplayed text (assumes the unplayed count has already been set)
 		 */
        public void set_unplayed_text() {
            string count_string = null;
            if(unplayed_count > 0) {
                count_string = _("%d episodes, %d unplayed".printf(podcast.episodes.size, unplayed_count));
            } else {
                count_string = _("%d episodes".printf(podcast.episodes.size));
            }
            count_label.set_text(count_string);
        }
    }  
}
