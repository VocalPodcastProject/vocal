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

    public class DirectoryView : Gtk.Box {

        public signal void new_subscription (string url);

        private iTunesProvider itunes;
        private Gtk.FlowBox flowbox;
        public Gtk.Button return_button;
        public Gtk.Button forward_button;
        private Gtk.Button first_run_continue_button;

        private Gtk.Box loading_box;

        private Gtk.ScrolledWindow scrolled_window;

        private bool top_podcasts_loaded = false;

        public DirectoryView (iTunesProvider itunes_provider) {

            this.set_orientation (Gtk.Orientation.VERTICAL);
            this.vexpand = true;

            var itunes_title = new Gtk.Label (_ ("Most Popular Podcasts"));
            itunes_title.margin_top = 15;
            itunes_title.margin_bottom = 15;
            itunes_title.justify = Gtk.Justification.CENTER;
            itunes_title.halign = Gtk.Align.CENTER;
            itunes_title.valign = Gtk.Align.CENTER;
            itunes_title.get_style_context ().add_class ("title-2");

            itunes_title.vexpand = false;
            itunes_title.hexpand = true;

            this.itunes = itunes_provider;
            this.append (itunes_title);

            loading_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            var spinner = new Gtk.Spinner ();
            var loading_label = new Gtk.Label (_ ("Loading iTunes Store"));
            loading_label.get_style_context ().add_class ("title-4");
            loading_box.append (loading_label);
            loading_box.append (spinner);
            this.append (loading_box);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.vexpand = true;
            this.append (scrolled_window);

        }

        public async void load_top_podcasts () {

            if (top_podcasts_loaded) {
                info ("Already loaded top 100 podcasts. Doing nothing.");
            }

            flowbox = new Gtk.FlowBox ();
            flowbox.selection_mode = Gtk.SelectionMode.NONE;
            flowbox.valign = Gtk.Align.START;
            scrolled_window.set_child (flowbox);

            var entries = itunes.get_top_podcasts (100);

            int i = 1; // counts the position for the "top 100"

            foreach (DirectoryEntry entry in entries) {
                DirectoryArt directory_art = new DirectoryArt (
                    entry.itunesUrl,
                    "%d. %s".printf (i, entry.title),
                    entry.artist,
                    entry.summary,
                    entry.artworkUrl170
                );
                directory_art.subscribe_button_clicked.connect ((url) => {
                    first_run_continue_button.sensitive = true;
                    new_subscription (url);
                });
                flowbox.append (directory_art);
                i++;
            }

            top_podcasts_loaded = true;
            loading_box.hide();
        }
    }
}
