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

  Additional contributors/authors:

  * Artem Anufrij <artem.anufrij@live.de>

***/


using Gtk;
using GLib;
using Granite;

namespace Vocal {

    public class DirectoryArt : Gtk.Box {

        public signal void subscribe_button_clicked (string url);

        private Gtk.Popover details_popover;
        private Gtk.Label summary_label;
        private Gtk.Box button_box;

        public DirectoryArt (  // vala-lint=naming-convention
            string url,
            string title,
            string? artist,
            string? summary,
            string artworkUrl170,  // vala-lint=naming-convention
            bool? in_library = false
        ) {

            this.set_orientation (Gtk.Orientation.VERTICAL);

            this.width_request = 200;
            this.margin = 10;

            // Create labels for title and artist
            var label_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            var title_label = new Gtk.Label ("""<b>%s</b>""".printf (GLib.Markup.escape_text (title)));
            title_label.justify = Gtk.Justification.LEFT;
            title_label.use_markup = true;
            title_label.max_width_chars = 15;
            title_label.wrap = true;
            title_label.set_property ("xalign", 0);
            label_box.pack_start (title_label, false, false, 5);

            artist = artist ?? "";

            var artist_label = new Gtk.Label (artist);
            artist_label.justify = Gtk.Justification.LEFT;
            artist_label.max_width_chars = 15;
            artist_label.wrap = true;
            artist_label.set_property ("xalign", 0);
            label_box.pack_start (artist_label, false, false, 5);

            var details_button = new Gtk.Button.from_icon_name (
                Utils.check_elementary () ? "help-info-symbolic" : "dialog-information-symbolic",
                Gtk.IconSize.SMALL_TOOLBAR
            );
            details_button.valign = Gtk.Align.START;
            details_button.tooltip_text = _ ("Details");
            if (Utils.check_elementary ())
                details_button.relief = Gtk.ReliefStyle.NONE;

            details_popover = new Gtk.Popover (details_button);
            summary_label = new Gtk.Label ("");
            summary_label.wrap = true;
            details_popover.add (summary_label);

            details_button.clicked.connect (() => {
                if (summary.length > 0) {
                    summary_label.set_text (summary);
                } else if (url.contains ("itunes.apple")) {
                    var itunes = new iTunesProvider ();
                    string rss_url = itunes.get_rss_from_itunes_url (url);
                    var feed_parser = new FeedParser ();

                    string details_summary = feed_parser.find_description_from_file (rss_url);
                    if (details_summary == null || details_summary.strip ().length == 0) {
                        details_summary = _ ("No summary available.");
                    }

                    summary_label.set_text (details_summary);
                    feed_parser = null;
                }
                summary_label.max_width_chars = 64;
                summary_label.margin = 20;
                details_popover.show_all ();
            });

            var subscribe_button = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            subscribe_button.tooltip_text = _ ("Subscribe");
            if (Utils.check_elementary ())
                subscribe_button.relief = Gtk.ReliefStyle.NONE;
            subscribe_button.clicked.connect (() => {
                subscribe_button_clicked (url);
            });
            subscribe_button.valign = Gtk.Align.START;

            button_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            button_box.add (details_button);
            button_box.add (subscribe_button);
            button_box.margin = 5;
            button_box.margin_right = 0;

            var hor_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            hor_box.pack_start (label_box, true, true, 0);
            hor_box.pack_start (button_box, false, false, 0);

            hor_box.margin_left = 10;
            hor_box.margin_right = 10;


            // By default we're only given the 170px version, but the 600px is available
            var bigartwork = artworkUrl170.replace ("170", "600");

            // Load the album artwork
            var missing_pixbuf = new Gdk.Pixbuf.from_resource_at_scale (
                "/com/github/needleandthread/vocal/missing.png",
                200,
                200,
                true
            );
            var image = new Gtk.Image.from_pixbuf (missing_pixbuf);
            image.margin = 0;
            image.expand = false;
            image.pixel_size = 200;
            image.margin_top = 5;
            image.margin_bottom = 5;
            image.get_style_context ().add_class ("directory-art-image");
            this.pack_start (image, false, false, 0);


            ImageCache image_cache = new ImageCache ();
            image_cache.get_image.begin (bigartwork, (obj, res) => {
                Gdk.Pixbuf pixbuf = image_cache.get_image.end (res);
                if (pixbuf != null) {
                    image.clear ();
                    image.gicon = pixbuf;
                    image.pixel_size = 200;
                }
            });


            this.pack_start (hor_box, false, false, 0);

            if (Utils.check_elementary ()) {
                this.get_style_context ().add_class ("card");
            } else {
                this.get_style_context ().add_class ("directory-art");
            }
        }
    }
}
