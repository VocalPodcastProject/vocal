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

    public class MainWindow : Adw.ApplicationWindow {

        public signal void add_podcast();

        private Vocal.Application controller;
        private Gee.ArrayList<CoverArt> all_art;

        private WelcomeScreen welcome;

        private Gtk.FlowBox all_flowbox;
        private PodcastView podcast_view;
        private NewEpisodesView new_episodes_view;
        public PlaybackBox playbackbox;

        private Gtk.Button download_button;
        private Gtk.Box downloads_list;
        private GLib.List<DownloadDetailBox> active_downloads;

        private Adw.ViewStack viewstack;
        private Adw.ViewStack all_viewstack;
        private Gtk.ScrolledWindow all_scrolled;


        private Gtk.InfoBar infobar;
        private Gtk.Label infobar_label;

        public DirectoryView directory_view;
        public SearchResultsView search_box;

        public MainWindow (Vocal.Application app) {
            Object (application: app);

            controller = app;

            var style_manager = Adw.StyleManager.get_default();

            if (controller.settings.theme_preference == "system") {
                style_manager.color_scheme = Adw.ColorScheme.DEFAULT;
            } else if (controller.settings.theme_preference == "dark") {
                style_manager.color_scheme = Adw.ColorScheme.PREFER_DARK;
            } else {
                style_manager.color_scheme = Adw.ColorScheme.PREFER_LIGHT;
            }

            this.set_default_size(controller.settings.window_width, controller.settings.window_height);

            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            this.set_content(box);

            var header = new Adw.HeaderBar();
            header.centering_policy = Adw.CenteringPolicy.STRICT;
            box.append(header);

            const string PRIMARY_STYLESHEET = """

                .badge {
                    border-radius: 100%;
                    padding: 12px;
                }

                .badge-light {
                    background-color: #fafafa;
                }

                .badge-dark {
                    background-color: rgb(48,48,48);
                }

                .flap {
                    background-color: rgba(0,0,0,1);
                }

                .flap * {
	                border-radius: 0;
                }

                .download-detail-box {
                    border-bottom: 0.5px solid #8a9580;
                }

                .squircle {
                    border-radius: 15px;
                }

                .squircle-top {
                    border-top-left-radius: 15px;
                    border-top-right-radius: 15px;
                }


                """;

            var css_provider = new Gtk.CssProvider ();
            css_provider.load_from_data (PRIMARY_STYLESHEET.data);
            Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);


            // Set up about window
            string[] authors = {"Nathan Dyer"};
		    string[] artists = {"Nathan Dyer (Initial Design)"};
		    string[] special_thanks = {"Dos Gatos Coffee Bar in beautiful, downtown Johsnon City, TN USA"};

		    var about_dialog = new Gtk.AboutDialog();
		    about_dialog.program_name = "Vocal";
		    about_dialog.logo_icon_name = "com.github.VocalPodcastProject.vocal";
		    about_dialog.authors = authors;
		    about_dialog.artists = artists;
		    about_dialog.copyright = "Copyright © 2022 Nathan Dyer and Vocal Project Contributors";
		    about_dialog.version = "4.0.0";
		    about_dialog.add_credit_section ("Special Thanks", special_thanks);

		    about_dialog.set_transient_for (this);
		    about_dialog.modal = true;
		    about_dialog.close_request.connect(() => {
                about_dialog.hide();
                return true;
            });

            viewstack = new Adw.ViewStack();

            all_viewstack = new Adw.ViewStack();
            all_flowbox = new Gtk.FlowBox ();
            all_scrolled = new Gtk.ScrolledWindow();
            all_scrolled.child = all_flowbox;
            podcast_view = new PodcastView (controller);

            welcome = new WelcomeScreen();

            all_viewstack.add(welcome);
            all_viewstack.add(all_scrolled);
            all_viewstack.add(podcast_view);


            podcast_view.go_back.connect(() => {
                all_viewstack.set_visible_child(all_scrolled);
            });



            podcast_view.play_episode_requested.connect((episode) => {
                controller.player.set_episode(episode);
                controller.player.play();
            });

            controller.player.track_changed.connect ((episode_title, podcast_name, artwork_uri, duration, description) => {
                playbackbox.set_info_title(episode_title, podcast_name);
                playbackbox.set_description(description);
                playbackbox.show_info_title();
            });

            podcast_view.download_episode_requested.connect(download_episode);

            podcast_view.download_all_requested.connect( () => {
                foreach (Episode e in podcast_view.podcast.episodes) {
                    download_episode (e);
                }
            });

            podcast_view.delete_podcast_requested.connect (on_remove_request);

            podcast_view.enqueue_episode.connect((episode) => {
                controller.library.enqueue_episode(episode);
            });

            new_episodes_view = new NewEpisodesView(app);
            new_episodes_view.add_all_new_to_queue.connect((episodes) => {
                foreach (Episode e in episodes) {
                    controller.library.enqueue_episode(e);
                }
            });

            new_episodes_view.mark_all_as_played.connect((episodes) => {
                foreach( Episode e in episodes) {
                    controller.library.mark_episode_as_played(e);
                }

                populate_views.begin((obj, res) => {
                    populate_views.end(res);
                });
            });



            directory_view = new DirectoryView(new iTunesProvider());
            directory_view.load_top_podcasts.begin((obj,res) => {
                directory_view.load_top_podcasts.end(res);
            });
            search_box = new SearchResultsView(app.library);

            viewstack.add_titled (all_viewstack, "Library", "Library");
            viewstack.add_titled (new_episodes_view, "New Episodes", "Fresh");
            viewstack.add_titled (directory_view, "Directory", "Directory");
            viewstack.add_titled (search_box, "Search", "Search");


            // Set up the IconView for all podcasts

            all_art = new Gee.ArrayList<CoverArt> ();
            all_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            all_flowbox.activate_on_single_click = true;
            all_flowbox.child_activated.connect (on_child_activated);
            all_flowbox.valign = Gtk.Align.START;
            all_flowbox.homogeneous = true;


            var all_stack_page = viewstack.get_page(all_viewstack);
            all_stack_page.icon_name = "user-bookmarks-symbolic";

            var new_stack_page = viewstack.get_page(new_episodes_view);
            new_stack_page.icon_name = "starred-symbolic";

            var store_stack_page = viewstack.get_page(directory_view);
            store_stack_page.icon_name = "application-rss+xml-symbolic";

            var search_stack_page = viewstack.get_page(search_box);
            search_stack_page.icon_name = "system-search-symbolic";

            var viewswitchertitle = new Adw.ViewSwitcherTitle();
            viewswitchertitle.set_stack(viewstack);
            header.set_title_widget(viewswitchertitle);


            infobar = new Gtk.InfoBar();
            infobar.show_close_button = true;
            infobar.response.connect((id) => {
                hide_infobar();
            });
            hide_infobar();


            infobar_label = new Gtk.Label("");
            infobar.add_child(infobar_label);

            var playbackbar = new Gtk.InfoBar();
            playbackbar.show_close_button = false;
            playbackbar.revealed = false;
            playbackbar.message_type = Gtk.MessageType.OTHER;

            playbackbox = new PlaybackBox();
            playbackbox.hexpand = true;
            playbackbar.add_child(playbackbox);
            playbackbar.hexpand = true;

            playbackbox.set_volume(controller.player.get_volume());

            playbackbox.rate_changed.connect((rate) => {
                controller.player.set_rate(rate);
            });

            playbackbox.volume_changed.connect((vol) => {
                controller.player.set_volume(vol);
            });

            playbackbox.position_changed.connect((pos) => {
                controller.player.set_percentage(pos);
            });

            playbackbox.remove_episode_from_queue.connect((e) => {
               controller.library.remove_episode_from_queue(e);
            });

            controller.player.position_updated.connect((p, d) => {
               playbackbox.set_position(p, d);
            });

            controller.player.end_of_stream.connect(() => {
                Episode next_episode = controller.library.get_next_episode_in_queue();
                if(next_episode != null) {
                    controller.player.pause();
                    controller.player.set_episode(next_episode);
                    controller.player.play();
                } else {
                    playbackbox.hide_info_title();
                }
            });

            controller.library.queue_changed.connect (() => {
                playbackbox.queue_box.set_queue (controller.library.queue);
            });


            box.append(playbackbar);
            box.append(infobar);
            box.append(viewstack);

            var viewswitcherbar = new Adw.ViewSwitcherBar();
            viewswitcherbar.set_stack(viewstack);
            box.append(viewswitcherbar);

            viewswitchertitle.bind_property ("title_visible", viewswitcherbar, "reveal", BindingFlags.DEFAULT);


            var settings_dialog = new SettingsDialog(this);
            var settings_button = new Gtk.Button.from_icon_name("open-menu-symbolic");
            settings_button.set_tooltip_text("Menu");
            var settings_popover = new Gtk.Popover();
            settings_popover.set_parent(settings_button);
            settings_popover.set_autohide(true);

            var settings_list = new Gtk.ListBox();
            settings_list.selection_mode = Gtk.SelectionMode.NONE;

            var check_for_updates_label = new Gtk.Label("Check for updates");
            check_for_updates_label.halign = Gtk.Align.FILL;
            check_for_updates_label.hexpand = true;
            settings_list.append(check_for_updates_label);

            var add_podcast_label = new Gtk.Label("Add podcast");
            var import_podcast_label = new Gtk.Label("Import podcasts");
            var export_podcast_label = new Gtk.Label("Export podcasts");
            var sync_label = new Gtk.Label("Set Up Sync");
            var settings_label = new Gtk.Label("Preferences");
            var about_label = new Gtk.Label("About");
            var donate_label = new Gtk.Label("Buy the Developer a Coffee");

            settings_list.append(add_podcast_label);
            settings_list.append(import_podcast_label);
            settings_list.append(export_podcast_label);
            settings_list.append(sync_label);
            settings_list.append(settings_label);
            settings_list.append(about_label);
            settings_list.append(donate_label);

            settings_list.row_activated.connect((row) => {
                if(row.child == about_label) {
                    about_dialog.show();
                } else if (row.child == settings_label) {
                    settings_dialog.show();
                } else if (row.child == import_podcast_label) {
                    import_podcasts ();
                } else if (row.child == export_podcast_label) {
                    export_podcasts ();
                } else if (row.child == add_podcast_label) {
                    add_podcast();
                } else if (row.child == donate_label) {
                    string ls_stdout;
                    string ls_stderr;
                    int ls_status;

                    try {
                        Process.spawn_command_line_sync("xdg-open https://ko-fi.com/nathandyer",
                            out ls_stdout,
                            out ls_stderr,
                            out ls_status);

                    } catch (SpawnError e) {
                        warning ("Error: %s\n", e.message);
                    }
                } else if (row.child == check_for_updates_label) {
                    controller.on_update_request();
                } else if (row.child == sync_label) {
                    var sync_dialog = new SyncDialog(controller, this);
                    sync_dialog.show();
                }
            });

            settings_popover.set_child(settings_list);
            settings_button.clicked.connect(() => {
               settings_popover.popup();
            });

            header.pack_end(settings_button);

            welcome.add_feed.connect(() => {
                add_podcast();
            });
            welcome.import.connect(() => {
                import_podcasts();
            });
            welcome.directory.connect(() => {
                viewstack.set_visible_child(directory_view);
            });
            welcome.search.connect(() => {
                viewstack.set_visible_child(search_box);
            });

            download_button = new Gtk.Button.from_icon_name ("document-save-symbolic");
            download_button.has_tooltip = true;
            download_button.tooltip_text = _ ("Download episode");
            download_button.hide();

            var download_popover = new Gtk.Popover();
            download_popover.set_parent(download_button);
            download_popover.set_autohide(true);

            downloads_list = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            active_downloads = new GLib.List<DownloadDetailBox>();
            download_popover.set_child(downloads_list);

            download_button.clicked.connect(() => {
                download_popover.popup();
            });

            header.pack_end(download_button);

            var play_button = new Gtk.Button.from_icon_name("media-playback-start-symbolic");
            var skip_back_button = new Gtk.Button.from_icon_name("media-seek-backward-symbolic");
            var skip_forward_button = new Gtk.Button.from_icon_name("media-seek-forward-symbolic");

            play_button.clicked.connect(() => {
                if(app.player.playing) {
                    app.player.pause();
                } else {
                    app.player.play();
                }
                play_button.icon_name = "media-playback-start-symbolic";
                play_button.tooltip_text = "Play";
            });

            controller.player.playback_status_changed.connect((status) => {
                if (status == "Playing") {
                    play_button.icon_name = "media-playback-pause-symbolic";
                    play_button.tooltip_text = "Pause";
                } else {
                    play_button.icon_name = "media-playback-start-symbolic";
                    play_button.tooltip_text = "Play";
                }
            });

            skip_back_button.clicked.connect(() => {
                app.player.skip_back(app.settings.fast_forward_seconds);
            });
            skip_forward_button.clicked.connect(() => {
                app.player.skip_forward(app.settings.rewind_seconds);
            });

            var playback_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

            playback_box.append(skip_back_button);
            playback_box.append(play_button);
            playback_box.append(skip_forward_button);

            header.pack_start(playback_box);

            var disclosure_button = new Gtk.Button.from_icon_name("go-down-symbolic");
            header.pack_start(disclosure_button);

            disclosure_button.clicked.connect(() => {
                if (playbackbar.revealed == false) {
                    playbackbar.revealed = true;
                    disclosure_button.icon_name = "go-up-symbolic";
                } else {
                    playbackbar.revealed = false;
                    disclosure_button.icon_name = "go-down-symbolic";
                }
            });

            hide_infobar();

            search_box.podcast_selected.connect((podcast) => {
                controller.highlighted_podcast = podcast;
                show_details(podcast);
            });

            search_box.episode_selected.connect((podcast, episode) => {
                controller.highlighted_podcast = podcast;
                show_details(podcast);
                podcast_view.highlight_episode(episode);
            });

            controller.update_status_changed.connect((currently_updating) => {
                if (!currently_updating) {
                    populate_views.begin((obj, res) => {
                        populate_views.end(res);
                    });

                }
            });
        }

        public void download_episode (Episode e) {
            download_button.show();
            var download_box = controller.library.download_episode(e);
            active_downloads.append(download_box);
            downloads_list.append(download_box);

            download_box.ready_for_removal.connect(() => {

                active_downloads.remove(download_box);
                downloads_list.remove(download_box);

                if(active_downloads.length() < 1) {
                    download_button.hide();
                }

                if(podcast_view.current_episode == e) {
                    podcast_view.shownotes.check_attributes ();
                }
            });
        }


        public async void populate_views () {

            GLib.Idle.add(populate_views.callback);

            yield;

            if (!controller.currently_repopulating) {

                info ("Populating the main podcast view.");
                controller.currently_repopulating = true;

                // If it's not the first run or newly launched go ahead and remove all the widgets from the flowboxes
                if (!controller.first_run && !controller.newly_launched) {
                    for (int i = 0; i < all_art.size; i++) {
                        all_flowbox.remove (all_flowbox.get_child_at_index (0));
                    }

                    all_art.clear ();
                }

                info ("Refilling library.");
                controller.library.refill_library.begin ((obj,res) => {
                    controller.library.refill_library.end(res);

                    // Clear flags since we have an established controller.library at this point
                    controller.newly_launched = false;
                    controller.first_run = false;

                    if(controller.library.podcasts.size > 0) {
                        all_viewstack.set_visible_child(all_scrolled);
                    }

                    foreach (Podcast podcast in controller.library.podcasts) {
                        CoverArt a = new CoverArt (podcast, true);
                        a.get_style_context ().add_class ("card");
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
                        all_flowbox.append(a);
                    }


                    controller.currently_repopulating = false;

                    new_episodes_view.populate_episodes_list.begin ((obj,res) => {
                        new_episodes_view.populate_episodes_list.end(res);
                    });

                    new_episodes_view.play_episode_requested.connect((episode) => {
                        controller.player.set_episode(episode);
                        controller.player.play();
                        playbackbox.set_info_title(episode.title, episode.parent.name);
                        playbackbox.set_description(episode.description);
                    });
                });
            }

        }

        public void show_library() {
            all_viewstack.set_visible_child(all_scrolled);
        }

        private void on_child_activated (Gtk.FlowBoxChild child) {
            Gtk.FlowBox parent = child.parent as Gtk.FlowBox;
            CoverArt art = parent.get_child_at_index (child.get_index ()).get_child () as CoverArt;
            parent.unselect_all ();
            controller.highlighted_podcast = art.podcast;
            show_details (art.podcast);
        }

        private void show_details (Podcast podcast) {
            viewstack.set_visible_child(all_viewstack);
            all_viewstack.set_visible_child(podcast_view);
            podcast_view.set_podcast.begin(podcast, (obj, res) => {
                podcast_view.set_podcast.end(res);
            });
        }


        public void show_infobar (string info, Gtk.MessageType type) {
            infobar_label.label = info;
            infobar.message_type = type;
            infobar.revealed = true;
        }

        public void hide_infobar () {
            infobar.revealed = false;
        }

        /*
         * Create a file containing the current controller.library subscription export
         */
        public void export_podcasts () {
            //Create a new file chooser dialog and allow the user to import the save configuration
            var file_chooser = new Gtk.FileChooserDialog ("Save Subscriptions to OPML File",
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

            file_chooser.show();

            file_chooser.response.connect ((response) => {
                if (response == Gtk.ResponseType.ACCEPT) {
                    var file = file_chooser.get_file();
                    string file_name = (file.get_path ());
                    if (!file_name.contains(".opml")) {
                        file_name = file_name + ".opml";
                    }
                    controller.library.export_to_OPML (file_name);
                }
                file_chooser.destroy ();
            });


        }

        /*
         * Choose a file to import to the controller.library
         */
        public void import_podcasts () {

            controller.currently_importing = true;
            Gtk.FileChooserDialog file_chooser = null;

            file_chooser = new Gtk.FileChooserDialog ("Import from OPML File",
                      this,
                      Gtk.FileChooserAction.OPEN,
                      _ ("Cancel"), Gtk.ResponseType.CANCEL,
                      _ ("Open"), Gtk.ResponseType.ACCEPT);

            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.set_filter_name (_ ("All files"));
            all_files_filter.add_pattern ("*");

            var opml_filter = new Gtk.FileFilter ();
            opml_filter.set_filter_name (_ ("OPML files"));
            opml_filter.add_mime_type ("text/x-opml+xml");

            file_chooser.add_filter (opml_filter);
            file_chooser.add_filter (all_files_filter);

            file_chooser.modal = true;

            file_chooser.show();

            file_chooser.response.connect ((response) => {
                if (response == Gtk.ResponseType.ACCEPT) {
                    show_infobar ("Importing Podcasts", Gtk.MessageType.INFO);
                    var file = file_chooser.get_file();
                    string file_name = (file.get_path ());

                    controller.library.add_from_OPML.begin (file_name, false, false, (obj, res) => {

                        Gee.ArrayList<string> failed_feed_list = controller.library.add_from_OPML.end (res);

                        if (failed_feed_list.size == 0) {
                            info ("Successfully imported all podcasts from OPML.");
                        } else {
                            string failed_feeds = "";
                            foreach (string failed_feed in failed_feed_list) {
                                failed_feeds = "%s\n %s".printf (failed_feeds, failed_feed);
                            }
                            string error_message = "Vocal was unable to import podcasts from the following feeds in the OPML file. \n%s\n".printf (failed_feeds);
                            show_infobar (error_message, Gtk.MessageType.ERROR);
                        }

                        populate_views.begin((obj, res) => {
                            populate_views.end(res);
                        });
                    });
                }

                file_chooser.destroy ();
            });
        }

        public void show_name_labels() {
            foreach(CoverArt a in all_art) {
                a.show_name_label();
            }
        }

        public void hide_name_labels() {
            foreach(CoverArt a in all_art) {
                a.hide_name_label();
            }
        }

        /*
         * Called when the user requests to remove a podcast from the controller.library via the right-click menu
         */
        public void on_remove_request () {
            if (controller.highlighted_podcast != null) {
                Gtk.MessageDialog msg = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE,
                       _ ("Are you sure you want to remove %s from your library?"),
                       controller.highlighted_podcast.name.replace ("%27", "'"));


                msg.add_button (_ ("No"), Gtk.ResponseType.NO);
                Gtk.Button delete_button = (Gtk.Button) msg.add_button (_ ("Yes"), Gtk.ResponseType.YES);
                delete_button.get_style_context ().add_class ("destructive-action");

                msg.response.connect ((response_id) => {
                    switch (response_id) {
                        case Gtk.ResponseType.YES:
                            controller.library.remove_podcast (controller.highlighted_podcast);
                            controller.highlighted_podcast = null;
                            if ( controller.library.empty ()) {
                                 all_viewstack.set_visible_child(welcome);
                            } else {
                                all_viewstack.set_visible_child(all_scrolled);
                                populate_views.begin((obj, res) => {
                                    populate_views.end(res);
                                });
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
    }
}

