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

namespace Vocal {


    public class AddFeedDialog : Gtk.Dialog {

        public signal void add_podcast(string feed);

        public Gtk.Entry entry;
        public Gtk.Button add_feed_button;

        public AddFeedDialog (Window parent) {
            set_default_response (Gtk.ResponseType.OK);
            set_size_request (500, 150);
            set_modal (true);
            set_transient_for (parent);
            set_resizable (false);
            setup ();
            this.title = _ ("Add New Podcast");
        }

        /*
         * Sets up the properties of the dialog
         */
        private void setup () {
            var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            content_box.margin_end = 12;
            content_box.margin_start = 12;

            var add_label = new Gtk.Label (_ ("Add a new podcast feed to the library."));
            add_label.get_style_context().add_class("title-3");
            add_label.halign = Gtk.Align.CENTER;
            add_label.hexpand = true;
            add_label.margin_top = 12;

            entry = new Gtk.Entry ();
            entry.placeholder_text = _ ("Podcast feed web address");
            entry.activates_default = false;
            Utils.set_margins (entry, 18);
            entry.changed.connect (on_entry_changed);

            content_box.append (add_label);

            // Add items to box
            var cancel_button = (Gtk.Button) add_button ("_Cancel", Gtk.ResponseType.CANCEL);
            add_feed_button = (Gtk.Button)add_button ("_Add Podcast", Gtk.ResponseType.OK);
            add_feed_button.get_style_context ().add_class ("suggested-action");
            add_feed_button.sensitive = false;

            cancel_button.margin_bottom = 12;
            add_feed_button.margin_bottom = 12;
            add_feed_button.margin_end = 12;

            // Set up the text entry activate signal to "click" the add button
            entry.activate.connect (() => {
                if (add_feed_button.sensitive) {
                    add_feed_button.clicked ();
                }
            });


            this.get_content_area ().append (content_box);
            this.get_content_area ().append (entry);
            add_feed_button.clicked.connect(() => {
                add_podcast(entry.text);
                destroy();
            });

            cancel_button.clicked.connect(() => {
                destroy();
            });

        }

        /*
         * Set the button's sensitivity based on whether or not there is any input
         */
        private void on_entry_changed () {
            if (entry.text.length > 0) {
                add_feed_button.sensitive = true;
            } else {
                add_feed_button.sensitive = false;
            }
        }
    }
}
