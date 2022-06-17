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
 *
 * Additional contributors/authors:
 *     Artem Anufrij <artem.anufrij@live.de>
 *
 */


using Gtk;
using GLib;

namespace Vocal {

    public class DirectoryArt : Gtk.Box {

        public signal void subscribe_button_clicked (string url);

        private Gtk.Popover details_popover;
        private Gtk.Label summary_label;

        public DirectoryArt (  // vala-lint=naming-convention
            string url,
            string title,
            string? artist,
            string? summary,
            string artworkUrl170,  // vala-lint=naming-convention
            bool? in_library = false
        ) {

            this.set_orientation (Gtk.Orientation.VERTICAL);
            this.halign = Gtk.Align.CENTER;

            this.width_request = 200;
            this.margin_bottom = 12;

            // Create labels for title and artist
            var label_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            label_box.hexpand = true;

            var title_label = new Gtk.Label ("""<b>%s</b>""".printf (GLib.Markup.escape_text (title)));
            title_label.justify = Gtk.Justification.LEFT;
            title_label.use_markup = true;
            title_label.max_width_chars = 10;
            title_label.wrap = true;
            title_label.set_property ("xalign", 0);
            label_box.append (title_label);

            artist = artist ?? "";

            var artist_label = new Gtk.Label (artist);
            artist_label.justify = Gtk.Justification.LEFT;
            artist_label.max_width_chars = 10;
            artist_label.wrap = true;
            artist_label.set_property ("xalign", 0);
            label_box.append (artist_label);

            var details_button = new Gtk.Button.from_icon_name ("dialog-information-symbolic");
            details_button.valign = Gtk.Align.START;
            details_button.tooltip_text = _ ("Details");
            details_button.margin_start = 12;

            details_popover = new Gtk.Popover ();
            details_popover.set_parent(details_button);
            var details_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            summary_label = new Gtk.Label ("");
            summary_label.wrap = true;
            details_popover.set_child (details_box);

            details_button.clicked.connect (() => {
                if (summary.length > 0) {
                    summary_label.set_text (summary);
                } else if (url.contains ("podcasts.apple.com")) {

                    var itunes = new iTunesProvider ();
                    string rss_url = itunes.get_rss_from_itunes_url (url);

                    var feed_parser = new FeedParser ();

                    try {
                        string details_summary = feed_parser.find_description_from_file (rss_url);
                        if (details_summary == null || details_summary.strip ().length == 0) {
                            details_summary = _ ("No summary available.");
                        }

                        summary_label.set_text (details_summary);
                    } catch (Error e) {
                        warning(e.message);
                    }
                    feed_parser = null;
                }
                summary_label.max_width_chars = 32;
                details_popover.popup ();
            });

            var subscribe_button = new Gtk.Button.with_label ("Subscribe");
            subscribe_button.tooltip_text = _ ("Subscribe");
            subscribe_button.clicked.connect (() => {
                subscribe_button_clicked (url);
            });
            subscribe_button.valign = Gtk.Align.START;

            details_box.append(summary_label);
            details_box.append(subscribe_button);

            var hor_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            hor_box.append (label_box);
            hor_box.append (details_button);
            Utils.set_margins (hor_box, 12);

            // By default we're only given the 170px version, but the 600px is available
            var bigartwork = artworkUrl170.replace ("170", "600");

            // Load the album artwork
            var image = new Gtk.Image();
            try {
                var missing_pixbuf = new Gdk.Pixbuf.from_resource_at_scale (
                    "/com/github/vocalpodcastproject/vocal/missing.png",
                    200,
                    200,
                    true
                );
                image = new Gtk.Image.from_pixbuf(missing_pixbuf);
            } catch (Error e) {
                warning(e.message);
            }


            image.margin_start = 0;
            image.margin_end = 0;
            image.pixel_size = 200;
            image.get_style_context ().add_class ("directory-art-image");
            image.overflow = Gtk.Overflow.HIDDEN;
            image.get_style_context().add_class("squircle-top");
            this.append (image);


            ImageCache image_cache = new ImageCache ();
            image_cache.get_image_async.begin (bigartwork, (obj, res) => {
                Gdk.Pixbuf pixbuf = image_cache.get_image_async.end (res);
                if (pixbuf != null) {
                    image.clear ();
                    image.gicon = pixbuf;
                    image.pixel_size = 200;
                    image.overflow = Gtk.Overflow.HIDDEN;
                    image.get_style_context().add_class("squircle-top");
                }
            });

            this.append (hor_box);

            this.get_style_context ().add_class ("card");
        }
    }
}
