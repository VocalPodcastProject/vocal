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

    public class PodcastView : Gtk.Box {

        /* Signals */

        public signal void play_episode_requested (Episode e);
        public signal void enqueue_episode (Episode episode);
        public signal void download_episode_requested (Episode episode);
        public signal void delete_local_episode_requested (Episode episode);
        public signal void mark_episode_as_played_requested (Episode episode);
        public signal void mark_episode_as_unplayed_requested (Episode episode);
        public signal void pane_should_hide ();
        public signal void download_all_requested ();
        public signal void delete_podcast_requested ();
        public signal void unplayed_count_changed (int n);
        public signal void go_back ();

        public signal void new_cover_art_set (string path);


        public Podcast podcast;
        public Vocal.Application controller;
        public Episode current_episode;

        public Shownotes shownotes;
        private Gtk.ListBox listbox;
        private GLib.List<EpisodeDetailBox> episodes;
        private Gtk.Label title;
        private Gtk.Label description;
        private Gtk.Image art;


        /*
         * Constructor for a Sidepane given a parent window and pocast
         */
        public PodcastView (Vocal.Application controller) {
            this.controller = controller;

            this.orientation = Gtk.Orientation.VERTICAL;

            // Flap
            //
            // Boxed list
            //
            var flap = new Adw.Flap();
            flap.fold_policy = Adw.FlapFoldPolicy.AUTO;

            var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            var actionbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            actionbar.get_style_context ().add_class ("toolbar");

            Utils.set_margins(toolbar, 12);
            toolbar.margin_bottom = 0;

            string newest_icon_name = null;
            if (controller.settings.newest_episodes_first) {
                newest_icon_name = "view-sort-ascending-symbolic";
            } else {
                newest_icon_name = "view-sort-descending-symbolic";
            }
            var newest_episodes_first_button = new Gtk.Button.from_icon_name (newest_icon_name);
            if (controller.settings.newest_episodes_first) {
                newest_episodes_first_button.tooltip_text = _ ("Show newer episodes at the top of the list");
            } else {
                newest_episodes_first_button.tooltip_text = _ ("Show older episodes at the top of the list");
            }
            newest_episodes_first_button.clicked.connect (() => {
                if (controller.settings.newest_episodes_first) {
                    controller.settings.newest_episodes_first = false;
                    newest_episodes_first_button.icon_name = "view-sort-descending-symbolic";
                    newest_episodes_first_button.tooltip_text = _ ("Show older episodes at the top of the list");
                } else {
                    controller.settings.newest_episodes_first = true;
                    newest_episodes_first_button.icon_name = "view-sort-ascending-symbolic";
                    newest_episodes_first_button.tooltip_text = _ ("Show newer episodes at the top of the list");
                }

                reset_episode_list ();
                populate_episodes.begin ((obj, res) => {
                    populate_episodes.end(res);
                });
            });

            var add_unplayed_to_queue = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_unplayed_to_queue.tooltip_text = "Add all unplayed episodes to queue";
            add_unplayed_to_queue.clicked.connect (() => {
                foreach (EpisodeDetailBox b in episodes) {
                    if (b.episode.status == EpisodeStatus.UNPLAYED) {
                        enqueue_episode (b.episode);
                    }
                }
            });

            var download_all = new Gtk.Button.from_icon_name ("document-save-symbolic");
            download_all.tooltip_text = _ ("Download all episodes");
            download_all.clicked.connect (() => {
                download_all_requested ();
            });

            var delete_podcast = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            delete_podcast.tooltip_text = _("Delete podcast from library");
            delete_podcast.clicked.connect(() => {
                delete_podcast_requested ();
            });

            var mark_as_played = new Gtk.Button.from_icon_name ("emblem-default-symbolic");
            mark_as_played.tooltip_text = _("Mark all episodes as played");
            mark_as_played.clicked.connect (() => {
                foreach (EpisodeDetailBox e in episodes) {
                    controller.library.mark_episode_as_played(e.episode);
                    e.mark_as_played();
                }
            });

            var mark_as_new = new Gtk.Button.from_icon_name ("star-new-symbolic");
            mark_as_new.tooltip_text = _("Mark all episodes as unplayed");
            mark_as_new.clicked.connect( () => {
                foreach (EpisodeDetailBox e in episodes) {
                    e.mark_as_unplayed();
                    controller.library.mark_episode_as_unplayed(e.episode);
                }
            });

            var go_back_button = new Gtk.Button.from_icon_name("go-previous-symbolic");
            go_back_button.clicked.connect (() => { go_back (); });
            go_back_button.get_style_context ().add_class ("back-button");

            var show_flap_button = new Gtk.Button.from_icon_name ("sidebar-show-symbolic");
            show_flap_button.tooltip_text = "Show episodes list";
            show_flap_button.clicked.connect(() => {
                if(flap.reveal_flap) {
                    flap.reveal_flap = false;
                } else {
                    flap.reveal_flap = true;
                }
            });

            title = new Gtk.Label("Podcast Title");
            title.get_style_context().add_class("title-2");
            title.wrap = true;
            title.max_width_chars = 10;

            description = new Gtk.Label("Description");
            description.wrap = true;
            description.max_width_chars = 10;
            title.get_style_context().add_class("title-3");

            art = new Gtk.Image();

            var textbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            textbox.append(title);
            textbox.append(description);

            var podcast_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            podcast_content.append (art);
            podcast_content.append(textbox);

            actionbar.append (go_back_button);
            actionbar.append (show_flap_button);
            var spacer = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            spacer.hexpand = true;
            actionbar.append(spacer);

            toolbar.append (podcast_content);
            toolbar.halign = Gtk.Align.CENTER;
            toolbar.hexpand = true;

            actionbar.append (mark_as_played);
            actionbar.append (mark_as_new);
            actionbar.append (add_unplayed_to_queue);
            actionbar.append (newest_episodes_first_button);
            actionbar.append (download_all);
            actionbar.append (delete_podcast);

            this.append (actionbar);

            listbox = new Gtk.ListBox();
            listbox.get_style_context().add_class ("boxed-list");


            listbox.row_activated.connect(on_row_activated);

            var list_scrolled = new Gtk.ScrolledWindow ();
            list_scrolled.child = listbox;
            list_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            list_scrolled.width_request = 400;
            list_scrolled.vexpand = true;

            // Just putting the scrolled list in a flap makes it transparent
            flap.flap = list_scrolled;
            flap.flap.get_style_context().add_class("flap");

            shownotes = new Shownotes();
            shownotes.margin_start = 6;
            shownotes.get_style_context().add_class("library-toolbar");
            shownotes.prepend(toolbar);

            shownotes.play.connect(() => { play_episode_requested(current_episode); });
            shownotes.download.connect(() => { download_episode_requested (current_episode); });
            shownotes.enqueue.connect(() => { enqueue_episode(current_episode); });
            shownotes.mark_as_new.connect(on_mark_as_new);
            shownotes.mark_as_played.connect(on_mark_as_played);
            shownotes.copy_shareable_link.connect(on_copy_shareable_link);
            shownotes.send_tweet.connect(on_tweet);
            shownotes.copy_direct_link.connect(on_link_to_file);


            flap.content = shownotes;
            this.append(flap);

        }

        public async void set_podcast (Podcast p) {

            GLib.Idle.add(this.set_podcast.callback);

            if(this.podcast != p) {

                this.podcast = p;
                current_episode = null;
                reset_episode_list ();

                title.set_text(p.name);
                description.set_text(Utils.html_to_markup (p.description));

                ImageCache image_cache = new ImageCache ();
                image_cache.get_image_async.begin (p.remote_art_uri, (obj, res) => {
                    Gdk.Pixbuf pixbuf = image_cache.get_image_async.end (res);
                    if (pixbuf != null) {
                        art.clear ();
                        art.gicon = pixbuf;
                        art.pixel_size = 150;
                        art.overflow = Gtk.Overflow.HIDDEN;
                        art.get_style_context().add_class("squircle");
                        art.show();
                    }
                });

                yield;

                populate_episodes.begin ((obj, res) => {
                    populate_episodes.end(res);
                    if(current_episode == null) {
                        on_row_activated(listbox.get_first_child () as Gtk.ListBoxRow);
                    } else {
                        highlight_episode (current_episode);
                    }
                });
            } else {
                yield;
            }
        }

        private GLib.ListStore sort_podcasts (bool newest_first) {

            GLib.ListStore elm = new GLib.ListStore ( typeof (Episode) );

            foreach (Episode e in podcast.episodes) {
                elm.insert_sorted (e, (a, b) => {
                    var e1 = (Episode) a;
                    var e2 = (Episode) b;
                    if (e2.datetime_released == null) {
                        if (e1.datetime_released == null) {
                            return 0;
                        }
                        return -1;
                    }
                    if (newest_first) {
                        return e2.datetime_released.compare (e1.datetime_released);
                    } else {
                        return e1.datetime_released.compare (e2.datetime_released);
                    }
                });
            }
            return elm;
        }

        public void highlight_episode (Episode e) {
            current_episode = e;
            bool found = false;
            int i = 0;
            while (!found && listbox.get_row_at_index(i) != null) {
                EpisodeDetailBox edb = listbox.get_row_at_index(i).child as EpisodeDetailBox;
                if(edb.episode.title == e.title) {
                    found = true;
                    listbox.row_activated(listbox.get_row_at_index(i));
                }
                i++;
            }
        }

        private void on_row_activated (Gtk.ListBoxRow row) {
            EpisodeDetailBox e = row.child as EpisodeDetailBox;
            current_episode = e.episode;
            shownotes.set_episode (e.episode);
            shownotes.show();
        }

        private void reset_episode_list() {
            while(listbox.get_last_child () != null) {
                listbox.remove(listbox.get_last_child ());
            }
            episodes = new GLib.List<EpisodeDetailBox>();
        }

        private async void populate_episodes () {
            GLib.Idle.add(this.populate_episodes.callback);

            var liststore = sort_podcasts(controller.settings.newest_episodes_first);

            for (int x = 0; ; x++) {
                var e = (Episode) liststore.get_item (x);
                if (e == null) { break; } // No more items
                var episode_box = new EpisodeDetailBox (e, controller, false);
                episodes.append (episode_box);
                listbox.append (episode_box);
            }

            yield;
        }

        private void on_mark_as_new() {
            foreach (EpisodeDetailBox e in episodes) {
                if (e.episode == current_episode) {
                    e.mark_as_unplayed();
                }
            }
            controller.library.mark_episode_as_unplayed (current_episode);
        }

        private void on_mark_as_played() {
            foreach (EpisodeDetailBox e in episodes) {
                if (e.episode == current_episode) {
                    e.mark_as_played();
                }
            }
            controller.library.mark_episode_as_played(current_episode);
        }

        private void on_link_to_file () {
            Gdk.Display display = controller.active_window.get_display ();
            var clipboard = display.get_clipboard();
            string uri = current_episode.uri;
            clipboard.set_text (uri);
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
            Gdk.Display display = controller.active_window.get_display ();
            var clipboard = display.get_clipboard();
            string uri = Utils.get_shareable_link_for_episode (current_episode);
            clipboard.set_text (uri);
        }


    }
}
