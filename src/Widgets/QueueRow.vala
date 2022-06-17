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

    public class QueueListRow : Gtk.ListBoxRow {
        public signal void update_queue (int oldPos, int newPos);  // vala-lint=naming-convention
        public signal void move_up (Episode e);
        public signal void move_down (Episode e);
        public signal void remove_episode (Episode e);

        public Episode episode;
        public Gtk.Box box;

        public QueueListRow (Episode episode) {
            this.episode = episode;

            box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.margin_start = 10;
            box.margin_end = 10;
            this.set_child (box);

            // Load the actual cover art
            var image = new Gtk.Image();
            ImageCache image_cache = new ImageCache ();
            image_cache.get_image_async.begin (episode.parent.remote_art_uri, (obj, res) => {
                Gdk.Pixbuf pixbuf = image_cache.get_image_async.end (res);
                if (pixbuf != null) {
                    image.clear ();
                    image.gicon = pixbuf;
                    image.pixel_size = 64;
                    image.show();
                }
            });

            box.append (image);

            Gtk.Label title_label = new Gtk.Label (
                Utils.truncate_string (
                    episode.title.replace ("%27", "'"),
                    35
                ) + "..."
            );
            box.append (title_label);

            Gtk.Button remove_button = new Gtk.Button.from_icon_name ("process-stop-symbolic");
            remove_button.set_tooltip_text (_ ("Remove episode from queue"));

            remove_button.clicked.connect (() => { remove_episode (episode); });

            box.append (remove_button);
        }
    }
}
