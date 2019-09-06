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

        public signal void play_episode_requested (Episode e);
        public signal void enqueue_episode (Episode episode);
        public signal void download_episode_requested (Episode episode);
        public signal void delete_local_episode_requested (Episode episode);
        public signal void mark_all_episodes_as_played_requested ();
        public signal void mark_episode_as_played_requested (Episode episode);
        public signal void mark_episode_as_unplayed_requested (Episode episode);
        public signal void pane_should_hide ();
        public signal void download_all_requested ();
        public signal void delete_podcast_requested ();
        public signal void unplayed_count_changed (int n);
        public signal void go_back ();

        public signal void new_cover_art_set (string path);


        public Podcast podcast;
        public Controller controller;
        public Episode current_episode;

        private Gtk.ListBox listbox;
        private Gtk.Paned paned;
        private Gtk.Toolbar toolbar;
        private Gtk.Box toolbar_box;
        private Gtk.Label name_label;
        private Gtk.Label count_label;
        private Gtk.Label description_label;
        private string count_string;

        private Gtk.Menu right_click_menu;

        public Gee.ArrayList<EpisodeDetailBox> boxes;
        private EpisodeDetailBox previously_selected_box;
        private EpisodeDetailBox previously_activated_box;
        private Gtk.ScrolledWindow scrolled;
        private int largest_box_size;
        public int unplayed_count;

        private Gtk.Box image_box;
        private Gtk.Box details_box;
        private Gtk.Box actions_box;
        private Gtk.Box label_box;

        private Gtk.Image image = null;
        public Shownotes shownotes;

        private Gtk.Box show_more_episodes_box;
        private Gtk.Image cc_image;

        /*
         * Constructor for a Sidepane given a parent window and pocast
         */
        public PodcastView (Controller controller) {
            this.controller = controller;

            largest_box_size = 500;

            this.orientation = Gtk.Orientation.VERTICAL;
            var horizontal_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            count_string = null;

            var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            toolbar.get_style_context ().add_class ("toolbar");
            toolbar.get_style_context ().add_class ("library-toolbar");

            var go_back_button = new Gtk.Button.with_label (_ ("Your Podcasts"));
            go_back_button.clicked.connect (() => { go_back (); });
            go_back_button.get_style_context ().add_class ("back-button");
            go_back_button.margin = 6;

            string newest_icon_name = null;
            if (controller.settings.newest_episodes_first) {
                newest_icon_name = "view-sort-ascending-symbolic";
            } else {
                newest_icon_name = "view-sort-descending-symbolic";
            }
            var newest_episodes_first_button = new Gtk.Button.from_icon_name (newest_icon_name, Gtk.IconSize.MENU);
            newest_episodes_first_button.margin = 6;
            if (controller.settings.newest_episodes_first) {
                newest_episodes_first_button.tooltip_text = _ ("Show newer episodes at the top of the list");
            } else {
                newest_episodes_first_button.tooltip_text = _ ("Show older episodes at the top of the list");
            }
            newest_episodes_first_button.clicked.connect (() => {
                if (controller.settings.newest_episodes_first) {
                    controller.settings.newest_episodes_first = false;
                    var image = new Gtk.Image.from_icon_name ("view-sort-descending-symbolic", Gtk.IconSize.MENU);
                    newest_episodes_first_button.image = image;
                    newest_episodes_first_button.tooltip_text = _ ("Show older episodes at the top of the list");
                } else {
                    controller.settings.newest_episodes_first = true;
                    var image = new Gtk.Image.from_icon_name ("view-sort-ascending-symbolic", Gtk.IconSize.MENU);
                    newest_episodes_first_button.image = image;
                    newest_episodes_first_button.tooltip_text = _ ("Show newer episodes at the top of the list");
                }

                reset_episode_list ();
                populate_episodes ();
            });

            var add_unplayed_to_queue = new Gtk.Button.with_label (_ ("Add New Episodes to Queue"));
            add_unplayed_to_queue.margin = 6;
            add_unplayed_to_queue.clicked.connect (() => {
                foreach (EpisodeDetailBox b in boxes) {
                    if (b.episode.status == EpisodeStatus.UNPLAYED) {
                        enqueue_episode (b.episode);
                    }
                }
            });

            var download_all = new Gtk.Button.from_icon_name (
                Utils.check_elementary () ? "browser-download-symbolic" : "document-save-symbolic",
                Gtk.IconSize.MENU
            );
            download_all.margin = 6;
            download_all.tooltip_text = _ ("Download all episodes");
            download_all.clicked.connect (() => {
                download_all_requested ();
            });

            var mark_as_played = new Gtk.Button.with_label (_ ("Mark All Played"));
            mark_as_played.clicked.connect (() => {
                mark_all_episodes_as_played_requested ();
            });
            mark_as_played.margin = 6;

            toolbar.pack_start (go_back_button, false, false, 0);
            toolbar.pack_end (mark_as_played, false, false, 0);
            toolbar.pack_end (add_unplayed_to_queue, false, false, 0);
            toolbar.pack_end (newest_episodes_first_button, false, false, 0);
            toolbar.pack_end (download_all, false, false, 0);
            this.pack_start (toolbar, false, true, 0);

            var edit = new Gtk.Button.from_icon_name (
                Utils.check_elementary () ? "edit-symbolic" : "document-properties-symbolic",
                Gtk.IconSize.MENU
            );
            edit.tooltip_text = _ ("Edit podcast details");
            edit.button_press_event.connect ((e) => {
                var edit_menu = new Gtk.Menu ();
                var change_cover_art_item = new Gtk.MenuItem.with_label (_ ("Select different cover art"));
                var creative_commons_override_button = new Gtk.MenuItem.with_label (
                    _ ("Set podcast license to Creative Commons")
                );
                change_cover_art_item.activate.connect (on_change_album_art);
                creative_commons_override_button.activate.connect (on_creative_commons_override);
                edit_menu.add (change_cover_art_item);
                edit_menu.add (creative_commons_override_button);
                edit_menu.attach_to_widget (edit, null);
                edit_menu.show_all ();
                edit_menu.popup (null, null, null, e.button, e.time);
                return true;
            });

            var remove = new Gtk.Button.with_label (_ ("Unsubscribe"));
            remove.clicked.connect (() => {
               delete_podcast_requested ();
            });
            remove.set_no_show_all (false);
            remove.get_style_context ().add_class ("destructive-action");
            remove.show ();

            image_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);


            details_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            label_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            name_label = new Gtk.Label ("Name");
            count_label = new Gtk.Label (count_string);
            name_label.max_width_chars = 15;
            name_label.wrap = true;
            name_label.justify = Gtk.Justification.CENTER;
            name_label.margin_bottom = 15;

            description_label = new Gtk.Label ("Description");
            description_label.max_width_chars = 15;
            description_label.wrap = true;
            description_label.wrap_mode = Pango.WrapMode.WORD;
            description_label.valign = Gtk.Align.START;
            description_label.get_style_context ().add_class ("podcast-view-description");

            // Set up a scrolled window
            var description_window = new Gtk.ScrolledWindow (null, null);
            description_window.add (description_label);
            description_window.height_request = 130;
            description_window.hscrollbar_policy = Gtk.PolicyType.NEVER;

            name_label.get_style_context ().add_class ("h2");
            count_label.get_style_context ().add_class ("h4");

            label_box.pack_start (name_label, false, false, 5);
            label_box.pack_start (description_window, true, true, 0);

            label_box.pack_start (count_label, false, false, 0);


            // Creative commons
            // Load the album artwork
            var ccicon_name = "";
            if (Gtk.Settings.get_default ().gtk_application_prefer_dark_theme == true) {
                ccicon_name = "/com/github/needleandthread/vocal/creativecommons-light.png";
            } else {
                ccicon_name = "/com/github/needleandthread/vocal/creativecommons-dark.png";
            }
            var cc_pb = new Gdk.Pixbuf.from_resource_at_scale (ccicon_name, 151, 36, true);
            cc_image = new Gtk.Image.from_pixbuf (cc_pb);
            cc_image.margin = 12;
            cc_image.expand = false;
            cc_image.pixel_size = 32;

            label_box.pack_start (cc_image, false, false, 0);

            actions_box.pack_start (edit, true, true, 0);
            actions_box.pack_start (remove, true, true, 0);

            var vertical_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            vertical_box.pack_start (label_box, true, true, 0);
            vertical_box.pack_start (actions_box, false, false, 0);
            vertical_box.margin = 12;
            vertical_box.margin_bottom = 0;

            details_box.pack_start (vertical_box, true, true, 12);
            details_box.pack_start (image_box, false, false, 0);
            details_box.valign = Gtk.Align.FILL;
            details_box.hexpand = false;
            details_box.margin = 0;

            horizontal_box.pack_start (details_box, false, true, 0);

            var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
            separator.margin = 0;
            horizontal_box.pack_start (separator, false, false, 0);

            paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            paned.expand = true;
            horizontal_box.pack_start (paned, true, true, 0);

            shownotes = new Shownotes ();
            shownotes.play_button.clicked.connect (() => { play_episode_requested (null); });
            shownotes.queue_button.clicked.connect (() => { enqueue_episode_internal (); });
            shownotes.download_button.clicked.connect (() => { download_episode_requested_internal (); });
            shownotes.mark_as_played_button.clicked.connect (() => { mark_episode_as_played_requested_internal (); });
            shownotes.mark_as_new_button.clicked.connect (() => { mark_episode_as_new_requested_internal (); });
            shownotes.internet_archive_upload_requested.connect (() => {
                var settings = VocalSettings.get_default_instance ();
                if (settings.archive_access_key.length < 1 || settings.archive_secret_key.length < 1) {
                    Gtk.MessageDialog msg = new Gtk.MessageDialog (
                        controller.window,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.WARNING,
                        Gtk.ButtonsType.OK,
                        _ ("Before you can upload to the Internet Archive you must add your archive.org account's API keys. Visit https://archive.org/account/s3.php to see your keys, then paste them in the settings.")  // vala-lint=line-length
                    );

                    var image = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG);
                    msg.image = image;
                    msg.image.show_all ();

                    msg.response.connect ((response_id) => {
                        msg.destroy ();
                    });
                    msg.show ();
                } else if (current_episode.current_download_status == DownloadStatus.DOWNLOADED) {

                    var internet_archive_dialog = new InternetArchiveUploadDialog (controller.window, current_episode);
                    internet_archive_dialog.show_all ();

                } else {

                    Gtk.MessageDialog msg = new Gtk.MessageDialog (
                        controller.window,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.WARNING,
                        Gtk.ButtonsType.YES_NO,
                        _ ("You must download this episode first before uploading to the Internet Archive. Would you like to download this episode?")  // vala-lint=line-length
                    );

                    var image = new Gtk.Image.from_icon_name ("dialog-question", Gtk.IconSize.DIALOG);
                    msg.image = image;
                    msg.image.show_all ();

                    msg.response.connect ((response_id) => {
                        switch (response_id) {
                            case Gtk.ResponseType.YES:
                                download_episode_requested (current_episode);
                                break;
                            case Gtk.ResponseType.NO:
                                break;
                        }

                        msg.destroy ();
                    });
                    msg.show ();
                }
            });

            shownotes.copy_shareable_link.connect (on_copy_shareable_link);
            shownotes.send_tweet.connect (on_tweet);
            shownotes.copy_direct_link.connect (on_link_to_file);

            paned.pack2 (shownotes, true, true);

            boxes = new Gee.ArrayList<EpisodeDetailBox> ();
            scrolled = new Gtk.ScrolledWindow (null, null);

            listbox = new Gtk.ListBox ();
            listbox.button_press_event.connect (on_button_press_event);
            listbox.row_selected.connect (on_row_selected);
            listbox.row_activated.connect (on_row_activated);
            listbox.activate_on_single_click = false;
            listbox.selection_mode = Gtk.SelectionMode.MULTIPLE;
            listbox.expand = true;
            listbox.get_style_context ().add_class ("sidepane_listbox");
            listbox.get_style_context ().add_class ("view");

            show_more_episodes_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            show_more_episodes_box.pack_start (listbox, true, true, 0);

            scrolled.add (show_more_episodes_box);

            paned.pack1 (scrolled, true, true);

            this.pack_start (horizontal_box, true, true, 0);
        }

        // Convenience method for triggering the signal
        private void download_episode_requested_internal () {
            download_episode_requested (current_episode);
        }

        private void enqueue_episode_internal () {
            enqueue_episode (current_episode);
        }

        private void mark_episode_as_played_requested_internal () {
            if (current_episode.status != EpisodeStatus.PLAYED) {
                unplayed_count--;
                set_unplayed_text ();

                Gtk.ListBoxRow selected_row = listbox.get_selected_row ();
                boxes[selected_row.get_index ()].mark_as_played ();

                mark_episode_as_played_requested (current_episode);
            }

            if (shownotes.episode != null && current_episode == shownotes.episode) {
                shownotes.show_mark_as_new_button ();
            }
        }

        private void mark_episode_as_new_requested_internal () {
            if (current_episode.status != EpisodeStatus.UNPLAYED) {
                unplayed_count++;
                set_unplayed_text ();

                Gtk.ListBoxRow selected_row = listbox.get_selected_row ();
                boxes[selected_row.get_index ()].mark_as_unplayed ();

                mark_episode_as_unplayed_requested (current_episode);
            }

            if (shownotes.episode != null && current_episode == shownotes.episode) {
                shownotes.show_mark_as_played_button ();
            }
        }

        /*
         * Gets an episode's corresponding box index in the list of EpisodeDetailBoxes
         */
        public int get_box_index_from_episode (Episode e) {

            int index = 0;
            foreach (EpisodeDetailBox b in boxes) {
                if (b.episode == e) {
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
        public void mark_all_played () {
            foreach (EpisodeDetailBox b in boxes) {
                b.mark_as_played ();
            }
        }

        /*
         * Handler for when a box has a button press event
         */
        private bool on_button_press_event (Gdk.EventButton e) {
            if (e.button == 3 && podcast.episodes.size > 0) {

                GLib.List<weak ListBoxRow> selected_rows = listbox.get_selected_rows ();

                if (selected_rows.length () > 1) {
                    // Multiple rows selected
                    right_click_menu = new Gtk.Menu ();

                    var add_to_queue_menu_item = new Gtk.MenuItem.with_label (_ ("Add selected episodes to queue"));
                    add_to_queue_menu_item.activate.connect (() => {

                        foreach (ListBoxRow row in selected_rows) {
                            EpisodeDetailBox b = row.get_child () as EpisodeDetailBox;
                            enqueue_episode (b.episode);
                        }
                    });
                    right_click_menu.add (add_to_queue_menu_item);

                    var mark_played_menuitem = new Gtk.MenuItem.with_label (_ ("Mark selected episodes as played"));
                    mark_played_menuitem.activate.connect (() => {

                            foreach (ListBoxRow row in selected_rows) {
                                EpisodeDetailBox b = row.get_child () as EpisodeDetailBox;
                                mark_episode_as_played_requested (b.episode);
                                b.mark_as_played ();
                            }

                            reset_unplayed_count ();

                    });
                    right_click_menu.add (mark_played_menuitem);


                    var mark_unplayed_menuitem = new Gtk.MenuItem.with_label (_ ("Mark selected episodes as new"));
                    mark_unplayed_menuitem.activate.connect (() => {

                        foreach (ListBoxRow row in selected_rows) {
                            EpisodeDetailBox b = row.get_child () as EpisodeDetailBox;
                            mark_episode_as_unplayed_requested (b.episode);
                            b.mark_as_unplayed ();
                        }

                        reset_unplayed_count ();
                    });
                    right_click_menu.add (mark_unplayed_menuitem);


                    var delete_menuitem = new Gtk.MenuItem.with_label (_ ("Delete local files for selected episodes"));
                    delete_menuitem.activate.connect (() => {
                        Gtk.MessageDialog msg = new Gtk.MessageDialog (
                            controller.window,
                            Gtk.DialogFlags.MODAL,
                            Gtk.MessageType.WARNING,
                            Gtk.ButtonsType.NONE,
                            _ ("Are you sure you want to delete the downloaded files for the selected episodes?")
                        );

                        msg.add_button ("_No", Gtk.ResponseType.CANCEL);
                        Gtk.Button delete_button = (Gtk.Button) msg.add_button ("_Yes", Gtk.ResponseType.YES);
                        delete_button.get_style_context ().add_class ("destructive-action");

                        var image = new Gtk.Image.from_icon_name ("dialog-question", Gtk.IconSize.DIALOG);
                        msg.image = image;
                        msg.image.show_all ();
                        msg.response.connect ((response_id) => {
                            switch (response_id) {
                                case Gtk.ResponseType.YES:

                                    foreach (ListBoxRow row in selected_rows) {
                                        EpisodeDetailBox b = row.get_child () as EpisodeDetailBox;
                                        delete_local_episode_requested (b.episode);
                                    }

                                    break;
                                case Gtk.ResponseType.NO:
                                    break;
                            }
                            msg.destroy ();
                        });
                        msg.show ();

                    });
                    right_click_menu.add (delete_menuitem);
                } else {

                    // Only a single row selected
                    ListBoxRow selected_row = listbox.get_row_at_y ((int)e.y);
                    EpisodeDetailBox b = selected_row.get_child () as EpisodeDetailBox;
                    current_episode = b.episode;

                    /*
                    if (current_episode_index >= 0 && current_episode_index < boxes.size) {
                        previously_selected_box = boxes[selected_row.get_index ()];
                    }
                    */

                    // Populate the right click menu based on the current conditions
                    right_click_menu = new Gtk.Menu ();

                    // Mark as played
                    if (current_episode.status == EpisodeStatus.UNPLAYED) {
                        var mark_played_menuitem = new Gtk.MenuItem.with_label (_ ("Mark as played"));
                        mark_played_menuitem.activate.connect (() => {
                            mark_episode_as_played_requested_internal ();
                        });
                        right_click_menu.add (mark_played_menuitem);

                    // Mark as unplayed
                    } else {
                        var mark_unplayed_menuitem = new Gtk.MenuItem.with_label (_ ("Mark as new"));
                        mark_unplayed_menuitem.activate.connect (() => {
                            mark_episode_as_new_requested_internal ();
                        });
                        right_click_menu.add (mark_unplayed_menuitem);
                    }

                    if (current_episode.current_download_status == DownloadStatus.DOWNLOADED) {
                        var delete_menuitem = new Gtk.MenuItem.with_label (_ ("Delete Local File"));

                        delete_menuitem.activate.connect (() => {
                            Gtk.MessageDialog msg = new Gtk.MessageDialog (
                                controller.window,
                                Gtk.DialogFlags.MODAL,
                                Gtk.MessageType.WARNING,
                                Gtk.ButtonsType.NONE,
                                _ ("Are you sure you want to delete the downloaded episode '%s'?").printf (
                                     current_episode.title.replace ("%27", "'")
                                )
                            );

                            msg.add_button ("_No", Gtk.ResponseType.CANCEL);
                            Gtk.Button delete_button = (Gtk.Button) msg.add_button ("_Yes", Gtk.ResponseType.YES);
                            delete_button.get_style_context ().add_class ("destructive-action");

                            var image = new Gtk.Image.from_icon_name ("dialog-question", Gtk.IconSize.DIALOG);
                            msg.image = image;
                            msg.image.show_all ();

                            msg.response.connect ((response_id) => {
                                switch (response_id) {
                                    case Gtk.ResponseType.YES:
                                        delete_local_episode_requested (current_episode);
                                        break;
                                    case Gtk.ResponseType.NO:
                                        break;
                                }

                                msg.destroy ();
                            });
                            msg.show ();

                        });

                        right_click_menu.add (delete_menuitem);
                    }
                }

                right_click_menu.show_all ();
                right_click_menu.popup (null, null, null, e.button, e.time);
            }

            return false;
        }

        public void set_podcast (Podcast podcast) {
            if (this.podcast == podcast) {
                return;
            }

            this.podcast = podcast;

            if (image != null) {
                image_box.remove (image);
                image = null;
            }

            try {
                var cover = GLib.File.new_for_uri (podcast.coverart_uri);
                var icon = new GLib.FileIcon (cover);
                image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DIALOG);
                image.pixel_size = 250;
                image.margin = 0;
                if (controller.on_elementary) {
                    image.get_style_context ().add_class ("card");
                } else {
                    image.get_style_context ().add_class ("podcast-view-coverart");
                }

                image_box.pack_start (image, true, true, 0);
            } catch (Error e) {
                error (e.message);
            }

            name_label.set_text (podcast.name.replace ("%27", "'"));
            description_label.set_text (podcast.description.replace ("""\n""", ""));

            reset_episode_list ();
            populate_episodes ();

            if (podcast.license == License.CC) {
                cc_image.no_show_all = false;
                cc_image.show ();
            } else {
                cc_image.no_show_all = true;
                cc_image.hide ();
            }

            // Select the first podcast
            var first_row = listbox.get_row_at_index (0);
            listbox.select_row (first_row);

            show_all ();
        }

        /*
         * When a row is activated, clear the unplayed icon if there is one and request
         * the corresponding episode be played
         */
        private void on_row_activated (ListBoxRow? row) {

            play_episode_requested (current_episode);
            foreach (EpisodeDetailBox b in boxes) {
                if (b.episode == current_episode) {
                    b.mark_as_now_playing ();
                } else {
                    b.clear_now_playing ();
                }
            }
            reset_unplayed_count ();
        }


        /*
         * When a row is selected, highlight it and show the details
         */
        private void on_row_selected () {

            GLib.List<weak ListBoxRow> rows = listbox.get_selected_rows ();
            if (rows.length () < 1) {
                return;
            }

            ListBoxRow new_row = listbox.get_selected_row ();
            if (controller.settings.newest_episodes_first) {
                current_episode = boxes[new_row.get_index ()].episode;
            } else {
                int new_index = boxes.size - new_row.get_index () - 1;
                current_episode = boxes[new_index].episode;
            }

            shownotes.episode = current_episode;
            shownotes.set_html (current_episode.description != " (null)" ? Utils.html_to_markup (current_episode.description) : _ ("No show notes available."));  // vala-lint=line-length
            shownotes.set_title (current_episode.title);
            shownotes.set_date (current_episode.datetime_released);

            // Check to see if the episode has been downloaded or not
            if (current_episode.current_download_status == DownloadStatus.DOWNLOADED) {
                shownotes.hide_download_button ();
            } else {
                shownotes.show_download_button ();
            }

            // Check to see if the episode can be uploaded to the archive or not
            if (current_episode.parent.license == License.CC) {
                shownotes.show_internet_archive_button ();
            } else {
                shownotes.hide_internet_archive_button ();
            }

            // Check the playback status
            if (current_episode.status == EpisodeStatus.PLAYED) {
                shownotes.show_mark_as_new_button ();
            } else {
                shownotes.show_mark_as_played_button ();
            }

            show_all ();
        }

        /*
         * Handler for when a single episode needs to be marked as remote (needs downloading)
         */
        public void on_single_delete (Episode e) {
            int index = get_box_index_from_episode (e);
            if (index != -1) {
                boxes[index].show_playback_button ();
                boxes[index].show_download_button ();
            }
        }

        /*
         * When a streaming button gets clicked set the current episode and treat
         * it like a row has been activated
         */
        private void on_streaming_button_clicked (Episode episode) {
            on_row_activated (null);
        }

        private void reset_episode_list () {
            foreach (var item in listbox.get_children ()) {
                listbox.remove (item);
            }

            boxes.clear ();
        }

        /*
         * Creates an EpisodeDetailBox for each episode and adds it to the window
         */
        public void populate_episodes () {

            // If there are episodes, create an episode detail box for each of them
            if (this.podcast.episodes.size > 0) {

                unplayed_count = 0;
                foreach (Episode current_episode in podcast.episodes) {

                    EpisodeDetailBox current_episode_box = new EpisodeDetailBox (current_episode, controller, false);
                    boxes.add (current_episode_box);

                    // Determine whether or not the episode has been played
                    if (current_episode.status == EpisodeStatus.UNPLAYED) {
                        unplayed_count++;
                    }
                }

                if (controller.settings.newest_episodes_first) {
                    foreach (EpisodeDetailBox box in boxes) {
                        listbox.add (box);
                        box.show_all ();
                    }
                } else {
                    foreach (EpisodeDetailBox box in boxes) {
                        listbox.prepend (box);
                        box.show_all ();
                    }
                }


            } else {
                // Otherwise, simply create a new label to tell user that the feed is empty
                var empty_label = new Gtk.Label (_ ("No episodes available."));
                empty_label.justify = Gtk.Justification.CENTER;
                empty_label.margin = 10;

                empty_label.get_style_context ().add_class ("h3");
                listbox.prepend (empty_label);
            }

            listbox.get_children ().foreach ((child) => {
                child.get_style_context ().add_class ("episode-list");
            });

            set_unplayed_text ();
        }

        /*
         * Resets the unplayed count and iterates through the boxes to obtain a new one
         */
        public void reset_unplayed_count () {

            int previous_count = unplayed_count;

            unplayed_count = 0;

            foreach (Episode e in podcast.episodes) {
                if (e.status == EpisodeStatus.UNPLAYED)
                    unplayed_count++;
            }

            set_unplayed_text ();

            // Is the number of unplayed episodes now different?
            if (previous_count != unplayed_count)
                unplayed_count_changed (unplayed_count);
        }

        private void on_change_album_art () {
            var file_chooser = new Gtk.FileChooserDialog (_ ("Select Album Art"),
                 controller.window,
                 Gtk.FileChooserAction.OPEN,
                 _ ("Cancel"), Gtk.ResponseType.CANCEL,
                 _ ("Open"), Gtk.ResponseType.ACCEPT);

            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.set_filter_name (_ ("All files"));
            all_files_filter.add_pattern ("*");

            var opml_filter = new Gtk.FileFilter ();
            opml_filter.set_filter_name (_ ("Image Files"));
            opml_filter.add_mime_type ("image/png");
            opml_filter.add_mime_type ("image/jpeg");

            file_chooser.add_filter (opml_filter);
            file_chooser.add_filter (all_files_filter);

            file_chooser.modal = true;

            int decision = file_chooser.run ();
            string file_name = file_chooser.get_filename ();

            file_chooser.destroy ();

            //If the user selects a file, get the name and parse it
            if (decision == Gtk.ResponseType.ACCEPT) {
                GLib.File cover = GLib.File.new_for_path (file_name);
                var icon = new GLib.FileIcon (cover);
                image.gicon = icon;
                image.pixel_size = 250;

                new_cover_art_set (file_name);
            }
        }

        /*
         * Overrides the autodetected creative commons setting to unlock Internet Archive features
         */
        private void on_creative_commons_override () {
            Gtk.MessageDialog msg = new Gtk.MessageDialog (
                controller.window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.WARNING,
                Gtk.ButtonsType.YES_NO,
                _ ("Vocal did not detect that this podcast is licensed as Creative Commons. Changing this will unlock Internet Archive integration for this podcast. Please make sure this change is correct before proceeding. Do you wish to make this change?")  // vala-lint=line-length
            );
            var image = new Gtk.Image.from_icon_name ("dialog-question", Gtk.IconSize.DIALOG);
            msg.image = image;
            msg.image.show_all ();

            msg.response.connect ((response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.YES:
                        podcast.license = License.CC;
                        controller.library.write_podcast_to_database (podcast);
                        cc_image.no_show_all = false;
                        cc_image.show ();
                        break;
                    case Gtk.ResponseType.NO:
                        break;
                }

                msg.destroy ();
            });
            msg.show ();
        }

        /*
          * Sets the unplayed text (assumes the unplayed count has already been set)
          */
        public void set_unplayed_text () {
            string count_string = null;
            if (unplayed_count > 0) {
                count_string = _ ("%d unplayed episodes".printf (unplayed_count));
            } else {
                count_string = "";
            }
            count_label.set_text (count_string);
        }

        public void select_episode (Episode e) {
            reset_episode_list ();
            populate_episodes ();

            for (int i = 0; i < boxes.size; i++) {
                ListBoxRow r = listbox.get_row_at_index (i);
                EpisodeDetailBox b = r.get_child () as EpisodeDetailBox;
                if (b.episode.title == e.title) {
                    listbox.select_row (r);
                    i = boxes.size;
                }
            }
        }

        private void on_link_to_file () {
            Gdk.Display display = controller.window.get_display ();
            Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
            string uri = current_episode.uri;
            clipboard.set_text (uri, uri.length);
        }

        private void on_tweet () {
            string uri = Utils.get_shareable_link_for_episode (current_episode);
            string message_text = GLib.Uri.escape_string (
                _ ("I'm listening to %s from %s").printf (
                    current_episode.title,
                    current_episode.parent.name
                )
            );
            string new_tweet_uri = "https://twitter.com/intent/tweet?text=%s&url=%s".printf (
                message_text,
                GLib.Uri.escape_string (uri)
            );
            Gtk.show_uri (null, new_tweet_uri, 0);
        }

        private void on_copy_shareable_link () {
            Gdk.Display display = controller.window.get_display ();
            Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
            string uri = Utils.get_shareable_link_for_episode (current_episode);
            clipboard.set_text (uri, uri.length);
        }
    }
}
