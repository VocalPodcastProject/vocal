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

    public class PodcastView : Gtk.Box {

        /* Signals */

    	public signal void play_episode_requested();
        public signal void enqueue_episode(Episode episode);
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
        public signal void go_back();
        
        public signal void new_cover_art_set(string path);


        public Podcast 			podcast;				// The parent podcast
        public MainWindow 		parent;					// The parent window
        private VocalSettings 	settings;				// Vocal's current settings
        public int 				current_episode_index;  // The index of the episode currently being used
        private int 			boxes_index;        	// Refers to an index in the list of boxes

        private Gtk.ListBox listbox;
        private Gtk.Paned paned;
        private Gtk.Toolbar toolbar;
        private Gtk.Box toolbar_box;
        private Gtk.Label name_label;
        private Gtk.Label count_label;
        private Gtk.Label description_label;
        private string count_string;

        private Gtk.Menu right_click_menu;

		public  Gee.ArrayList<EpisodeDetailBox> boxes;
		private EpisodeDetailBox previously_selected_box;
        private EpisodeDetailBox previously_activated_box;
		private Gtk.ScrolledWindow scrolled;
		private int largest_box_size;
		public  int  unplayed_count;
		private int limit;

		private Gtk.Box image_box;
		private Gtk.Box details_box;
		private Gtk.Box actions_box;
		private Gtk.Box label_box;

		private Gtk.Image image = null;
		public Shownotes shownotes;

		/*
		 * Constructor for a Sidepane given a parent window and pocast
		 */
        public PodcastView (MainWindow parent, Podcast? podcast, bool? on_elementary = true) {
            this.podcast = podcast;
            this.parent = parent;
            this.settings = VocalSettings.get_default_instance();

            largest_box_size = 500;

			this.current_episode_index = 0;
            this.boxes_index = 0;
			this.orientation = Gtk.Orientation.VERTICAL;
            var horizontal_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

			count_string = null;

            var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            toolbar.get_style_context().add_class("toolbar");
            toolbar.get_style_context().add_class("library-toolbar");

            var go_back_button = new Gtk.Button.with_label(_("Your Podcasts"));
            go_back_button.clicked.connect(() => { go_back(); });
            go_back_button.get_style_context().add_class("back-button");
            go_back_button.margin = 6;

            var mark_as_played = new Gtk.Button.with_label(_("Mark All Played"));
            mark_as_played.clicked.connect(() => {
                mark_all_episodes_as_played_requested();
            });
            mark_as_played.margin = 6;

            toolbar.pack_start(go_back_button, false, false, 0);
            toolbar.pack_end(mark_as_played, false, false, 0);
            this.pack_start(toolbar, false, true, 0);

            var download_all = new Gtk.Button.from_icon_name("browser-download-symbolic", Gtk.IconSize.MENU);
            download_all.tooltip_text = _("Download all episodes");
            download_all.clicked.connect(() => {
                download_all_requested();
            });

            var hide_played = new Gtk.Button.from_icon_name("view-list-symbolic", Gtk.IconSize.MENU);
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

            var edit = new Gtk.Button.from_icon_name("edit-symbolic", Gtk.IconSize.MENU);
            edit.tooltip_text = _("Edit podcast details");
            edit.button_press_event.connect((e) => {
                var edit_menu = new Gtk.Menu();
                var change_cover_art_item = new Gtk.MenuItem.with_label(_("Select different cover art"));
                change_cover_art_item.activate.connect(on_change_album_art);
                edit_menu.add(change_cover_art_item);
                edit_menu.attach_to_widget(edit, null);
                edit_menu.show_all();
                edit_menu.popup(null, null, null, e.button, e.time);
                return true;
            });

            var remove = new Gtk.Button.with_label(_("Unsubscribe"));
            remove.clicked.connect (() => {
               delete_podcast_requested();
            });
            remove.set_no_show_all(false);
            remove.get_style_context().add_class("destructive-action");
            remove.show();

            image_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            

            details_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            actions_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            label_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

			name_label = new Gtk.Label("Name");
			count_label = new Gtk.Label(count_string);
			name_label.max_width_chars = 15;
			name_label.wrap = true;
			name_label.justify = Gtk.Justification.CENTER;
            name_label.margin_bottom = 15;

            description_label = new Gtk.Label("Description");
            description_label.max_width_chars = 15;
            description_label.wrap = true;
            description_label.wrap_mode = Pango.WrapMode.WORD;
            description_label.valign = Gtk.Align.START;
            description_label.get_style_context().add_class("podcast-view-description");

            // Set up a scrolled window
            var description_window = new Gtk.ScrolledWindow(null, null);
            description_window.add(description_label);
            description_window.height_request = 180;
            description_window.hscrollbar_policy = Gtk.PolicyType.NEVER;

			Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H2, name_label);
            count_label.get_style_context().add_class("h4");

			label_box.pack_start(name_label, false, false, 5);
            label_box.pack_start(description_window, true, true, 0);

            var expander_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            expander_box.vexpand = true;

            label_box.pack_start(expander_box, true, true, 0);
			label_box.pack_start(count_label, false, false, 0);

			actions_box.pack_start(download_all, true, true, 0);
            actions_box.pack_start(edit, true, true, 0);
			actions_box.pack_start(hide_played, true, true, 0);
			actions_box.pack_start(remove, true, true, 0);

			var vertical_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
			vertical_box.pack_start(label_box, true, true, 0);
			vertical_box.pack_start(actions_box, false, false, 0);
            vertical_box.margin = 12;
            vertical_box.margin_bottom = 0;

            details_box.pack_start(vertical_box, true, true, 12);
			details_box.pack_start(image_box, false, false, 0);
            details_box.valign = Gtk.Align.FILL;
            details_box.hexpand = false;
            details_box.margin = 0;

			horizontal_box.pack_start(details_box, false, true, 0);

			var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
			separator.margin = 0;
			horizontal_box.pack_start(separator, false, false, 0);

			paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
			paned.expand = true;
			horizontal_box.pack_start(paned, true, true, 0);

			shownotes = new Shownotes();
            shownotes.play_button.clicked.connect(() => { play_episode_requested(); });
            shownotes.queue_button.clicked.connect(() => { enqueue_episode_internal(); });
            shownotes.download_button.clicked.connect(() => { download_episode_requested_internal(); });

			paned.pack2(shownotes, true, true);

            this.pack_start(horizontal_box, true, true, 0);

        }

        // Convenience method for triggering the signal
        private void download_episode_requested_internal() {
            download_episode_requested(podcast.episodes[current_episode_index]);
        }

        private void enqueue_episode_internal() {
            enqueue_episode(podcast.episodes[current_episode_index]);
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
                                 _("Are you sure you want to delete the downloaded episode '%s'?").printf(podcast.episodes[current_episode_index].title.replace("%27", "'")));


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

        public void set_podcast(Podcast podcast) {


        	this.podcast = podcast;

        	if(image != null) {
        		image_box.remove(image);
        		image = null;
        	}

        	try {
			    GLib.File cover = GLib.File.new_for_uri(podcast.coverart_uri);
                InputStream input_stream = cover.read();
                var pixbuf = new Gdk.Pixbuf.from_stream_at_scale(input_stream, 275, 275, true);


                image = new Gtk.Image.from_pixbuf(pixbuf);
                image.margin = 0;
                image.get_style_context().add_class("podcast-view-coverart");

            	image_box.pack_start(image, true, true, 0);


            } catch (Error e) {}

			name_label.set_text(podcast.name.replace("%27", "'"));
            description_label.set_text(GLib.Uri.unescape_string(podcast.description).replace("""\n""",""));

            populate_episodes();

            // Select the first podcast
            var first_row = listbox.get_row_at_index(0);
            listbox.select_row(first_row);

            show_all();


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
            if(rows.length() < 1)
                return;


            ListBoxRow new_row = listbox.get_selected_row();
            current_episode_index = (podcast.episodes.size - new_row.get_index() - 1);
            boxes_index = boxes.size - new_row.get_index() - 1;

            if(current_episode_index >= 0 && current_episode_index < boxes.size) {
                previously_selected_box = boxes[current_episode_index];
            }

            shownotes.set_html(podcast.episodes[current_episode_index].description != "(null)" ? podcast.episodes[current_episode_index].description.replace("%27", "'") : _("No show notes available."));
            shownotes.set_title(podcast.episodes[current_episode_index].title);
            shownotes.set_date(podcast.episodes[current_episode_index].datetime_released);

            // Check to see if the episode has been downloaded or not
            if(podcast.episodes[current_episode_index].current_download_status == DownloadStatus.DOWNLOADED) {
                shownotes.hide_download_button();
            } else {
                shownotes.show_download_button();
            }

            show_all();
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

            paned.remove(scrolled);
            scrolled = new Gtk.ScrolledWindow (null, null);
            listbox = new Gtk.ListBox();
            listbox.activate_on_single_click = false;
            listbox.selection_mode = Gtk.SelectionMode.MULTIPLE;
            listbox.expand = true;
            listbox.get_style_context().add_class("sidepane_listbox");
            listbox.get_style_context().add_class("view");


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
                    current_episode_box.margin_top = 6;
                    current_episode_box.margin_left = 6;
                    current_episode_box.border_width = 0;
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
                	var increase_button = new Gtk.Button.with_label(_("Show more episodes"));
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

            listbox.get_children().foreach((child) => {
                child.get_style_context().add_class("episode-list");
            });

            scrolled.add(listbox);

            paned.pack1(scrolled, true, true);


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
        
        private void on_change_album_art() {
            var file_chooser = new Gtk.FileChooserDialog (_("Select Album Art"),
                 parent,
                 Gtk.FileChooserAction.OPEN,
                 _("Cancel"), Gtk.ResponseType.CANCEL,
                 _("Open"), Gtk.ResponseType.ACCEPT);

            var all_files_filter = new Gtk.FileFilter();
            all_files_filter.set_filter_name(_("All files"));
            all_files_filter.add_pattern("*");

            var opml_filter = new Gtk.FileFilter();
            opml_filter.set_filter_name(_("Image Files"));
            opml_filter.add_mime_type("image/png");
            opml_filter.add_mime_type("image/jpeg");

            file_chooser.add_filter(opml_filter);
            file_chooser.add_filter(all_files_filter);

            file_chooser.modal = true;

            int decision = file_chooser.run();
            string file_name = file_chooser.get_filename();

            file_chooser.destroy();

            //If the user selects a file, get the name and parse it
            if (decision == Gtk.ResponseType.ACCEPT) {
                GLib.File cover = GLib.File.new_for_path(file_name);
                InputStream input_stream = cover.read();
                var pixbuf = new Gdk.Pixbuf.from_stream_at_scale(input_stream, 275, 275, true);

                image.pixbuf = pixbuf;
                
                new_cover_art_set(file_name);
            }
        }

		/*
 		 * Sets the unplayed text (assumes the unplayed count has already been set)
 		 */
        public void set_unplayed_text() {
            string count_string = null;
            if(unplayed_count > 0) {
                count_string = _("%d unplayed episodes".printf(unplayed_count));
            } else {
                count_string = _("");
            }
            count_label.set_text(count_string);
        }

        public void select_episode(Episode e) {

            populate_episodes(podcast.episodes.size);

            for(int i = 0; i < boxes.size; i++) {
                ListBoxRow r = listbox.get_row_at_index(i);
                EpisodeDetailBox b = r.get_child() as EpisodeDetailBox;
                if(b.episode.title == e.title) {
                    listbox.select_row(r);
                    i = boxes.size;
                }
            }
        }
    }
}
