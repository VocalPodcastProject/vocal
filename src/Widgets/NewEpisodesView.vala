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

using Gtk;
using Gee;
namespace Vocal {

    public class NewEpisodesView : Gtk.Box {

        private Application controller;
        private ListBox new_episodes_listbox;
        GLib.ListStore episodeListModel = new GLib.ListStore ( typeof (Episode) );
        public signal void go_back ();
        public signal void play_episode_requested (Episode episode);
        public signal void add_all_new_to_queue (GLib.List<Episode> episodes);
        public signal void mark_all_as_played (GLib.List<Episode> episodes);

        public NewEpisodesView (Application cont) {
            controller = cont;

            var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            toolbar.get_style_context ().add_class ("toolbar");
            toolbar.get_style_context ().add_class ("library-toolbar");

            this.append(toolbar);

            var new_episodes_label = new Gtk.Label (_ ("New Episodes"));
            new_episodes_label.get_style_context ().add_class ("title-2");
            new_episodes_label.margin_top = 12;
            new_episodes_label.margin_bottom = 12;
            this.append(new_episodes_label);

            var new_episodes_scrolled = new Gtk.ScrolledWindow ();
            new_episodes_scrolled.margin_start = 50;
            new_episodes_scrolled.margin_end = 50;
            new_episodes_scrolled.vexpand = true;
            new_episodes_listbox = new Gtk.ListBox ();
            new_episodes_listbox.get_style_context().add_class ("boxed-list");

            var add_all_to_queue_button = new Gtk.Button.with_label (_ ("Add all new episodes to the queue"));
            add_all_to_queue_button.halign = Gtk.Align.CENTER;
            add_all_to_queue_button.clicked.connect (() => {
                GLib.List<Episode> episodes = new GLib.List<Episode> ();
                for (int x = 0; ; x++) {
                    var e = (Episode) episodeListModel.get_item (x);
                    if (e == null) { break; } // No more items
                    episodes.append (e);
                }
                add_all_new_to_queue (episodes);
            });


            var mark_all_as_played_button = new Gtk.Button.with_label(_ ("Mark all as played"));
            mark_all_as_played_button.clicked.connect(() => {
                GLib.List<Episode> episodes = new GLib.List<Episode> ();
                for (int x = 0; ; x++) {
                    var e = (Episode) episodeListModel.get_item (x);
                    if (e == null) { break; } // No more items
                    episodes.append (e);
                }
                mark_all_as_played (episodes);

                populate_episodes_list ();
            });

            this.orientation = Gtk.Orientation.VERTICAL;

            new_episodes_scrolled.set_child (new_episodes_listbox);
            this.append(new_episodes_scrolled);

            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            button_box.halign = Gtk.Align.CENTER;
            Utils.set_margins(button_box, 12);
            button_box.append(add_all_to_queue_button);
            button_box.append(mark_all_as_played_button);

            this.append(button_box);
            new_episodes_listbox.activate_on_single_click = false;
            new_episodes_listbox.row_activated.connect (on_row_activated);

        }


        public async void populate_episodes_list () {

            GLib.Idle.add(this.populate_episodes_list.callback);

            yield;

            GLib.ListStore elm = new GLib.ListStore ( typeof (Episode) );

            foreach (Podcast p in controller.library.podcasts) {
                foreach (Episode e in p.episodes) {
                    if (e.status == EpisodeStatus.UNPLAYED) {
                        elm.insert_sorted (e, (a, b) => {
                                var e1 = (Episode) a;
                                var e2 = (Episode) b;
                                if (e2.datetime_released == null) {
                                    if (e1.datetime_released == null) {
                                        return 0;
                                    }
                                    return -1;
                                }
                                return e2.datetime_released.compare (e1.datetime_released);
                        });
                    }
                }
            }

            this.episodeListModel = elm;
            new_episodes_listbox.bind_model (elm, (item) => {
                return new EpisodeDetailBox ((Episode) item, controller, true);
            });
        }


        public void on_row_activated (Gtk.ListBoxRow row) {
            var index = row.get_index ();
            Episode ep = (Episode) episodeListModel.get_item (index);
            play_episode_requested (ep);
        }
    }
}

