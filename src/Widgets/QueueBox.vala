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
    public class QueueBox : Gtk.Box {
        public signal void update_queue (int oldPos, int newPos);  // vala-lint=naming-convention
        public signal void move_up (Episode e);
        public signal void move_down (Episode e);
        public signal void remove_episode (Episode e);
        public signal void play_episode_from_queue_immediately (Episode e);

        private QueueList episodes;

        private Gtk.Label label;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Box scrolled_box;

        public QueueBox () {

            label = new Gtk.Label (_ ("No episodes in queue"));
            label.get_style_context ().add_class ("title-3");
            Utils.set_margins(label, 12);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_size_request (400, 50);

            scrolled_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            scrolled_window.set_child (scrolled_box);

            scrolled_box.append (label);

            this.append (scrolled_window);
        }

        /*
         * Sets the current queue
         */
        public void set_queue (Gee.ArrayList<Episode> queue) {

            if (episodes != null) {
                scrolled_box.remove (episodes);
            }

            if (queue.size > 0) {
                hide_label ();

                episodes = new QueueList (queue);
                episodes.update_queue.connect ((oldPos, newPos) => { update_queue (oldPos, newPos); });
                episodes.row_activated.connect (on_row_activated);
                episodes.remove_episode.connect ((e) => { remove_episode (e); });
                scrolled_box.append (episodes);

            } else {
                show_label ();
            }
        }


        /*
         * Show the "no episodes in queue" label
         */
        private void show_label () {
            label.show ();
            scrolled_window.set_size_request (400, 60);
        }


        /*
         * Hide the "no episodes in queue" label
         */
        private void hide_label () {
            label.hide ();
            scrolled_window.set_size_request (400, 225);
        }


        /*
         * Called whenever the row is activated (when the user clicks it)
         */
        public void on_row_activated (Gtk.ListBoxRow row) {
            QueueListRow q = (QueueListRow) row;
            play_episode_from_queue_immediately (q.episode);
        }
  }

    public class QueueList : Gtk.Box {
        public signal void update_queue (int oldPos, int newPos);
        public signal void remove_episode (Episode e);
        public signal void row_activated(ListBoxRow row);

        public Gee.ArrayList<QueueListRow> rows;

        public QueueList (Gee.ArrayList<Episode> queue) {
            this.orientation = Gtk.Orientation.VERTICAL;
            var list_box = new Gtk.ListBox();
            list_box.selection_mode = Gtk.SelectionMode.NONE;
            rows = new Gee.ArrayList<QueueListRow> ();

            foreach (Episode e in queue) {
                QueueListRow listRow = new QueueListRow (e);

                listRow.remove_episode.connect ((e) => { remove_episode (e); });

                listRow.update_queue.connect ((oldPos, newPos) => { update_queue (oldPos, newPos); });

                append (listRow);
                rows.add (listRow);
            }

            list_box.row_activated.connect((row) => {
               row_activated(row);
            });
        }
    }
}
