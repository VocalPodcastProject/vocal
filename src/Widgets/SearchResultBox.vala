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

namespace Vocal {
    public class SearchResultBox : Gtk.Box {

        public signal void subscribe_to_podcast (string itunes_url);

        private Episode episode;
        private Podcast podcast;

        private string details;
        private string subscribe_url;

        private Gtk.Label summary_label;

        private string rss_url;
        private bool details_visible = false;
        private Gtk.Button subscribe_button;


        /*
         * Constructor for a box that contains a search result. SRs can be for a library episode, a library podcast, or
         * content on the iTunes Store
         */
        public SearchResultBox (
            Podcast? podcast,
            Episode? episode,
            string? details = null,
            string? subscribe_url = null
        ) {

            this.episode = episode;
            this.podcast = podcast;
            this.details = details;
            this.subscribe_url = subscribe_url;

            this.orientation = Gtk.Orientation.VERTICAL;

            // If it's an iTunes URL, find its matching generic RSS URL and set that for the subscribe link
            if (subscribe_url != null && subscribe_url.contains ("itunes.apple")) {
                var itunes = new iTunesProvider ();
                rss_url = itunes.get_rss_from_itunes_url (subscribe_url);
            } else if (subscribe_url != null) {
                rss_url = subscribe_url;
            }

            var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);

            // Do we only have a podcast?
            if (episode == null) {
                var missing_pixbuf = new Gdk.Pixbuf.from_resource_at_scale (
                    "/com/github/needleandthread/vocal/missing.png",
                    32,
                    32,
                    true
                );
                var image = new Gtk.Image.from_pixbuf (missing_pixbuf);
                image.margin = 0;
                image.expand = false;
                image.get_style_context ().add_class ("album-artwork");
                content_box.pack_start (image, false, false, 5);

                var image_cache = new ImageCache ();
                image_cache.get_image.begin (podcast.coverart_uri, (obj, res) => {
                    Gdk.Pixbuf pixbuf = image_cache.get_image.end (res);
                    if (pixbuf != null) {
                        image.clear ();
                        pixbuf = pixbuf.scale_simple (32, 32, Gdk.InterpType.BILINEAR);
                        image.set_from_pixbuf (pixbuf);
                    }
                });
                var label = new Gtk.Label (podcast.name.replace ("%27", "'"));
                label.set_property ("xalign", 0);
                label.ellipsize = Pango.EllipsizeMode.END;
                label.max_width_chars = 30;
                content_box.pack_start (label, true, true, 0);

            // If not, then we have an episode, which requires more info to be displayed
            } else {

                try {
                    GLib.File cover = GLib.File.new_for_uri (podcast.coverart_uri);
                    InputStream input_stream = cover.read ();
                    var pixbuf = new Gdk.Pixbuf.from_stream_at_scale (input_stream, 32, 32, true);
                    var image = new Gtk.Image.from_pixbuf (pixbuf);
                    image.margin = 0;
                    image.expand = false;
                    image.get_style_context ().add_class ("album-artwork");

                    content_box.pack_start (image, false, false, 5);
                } catch (Error e) {}

                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
                var title_label = new Gtk.Label (episode.title);
                var parent_label = new Gtk.Label (podcast.name.replace ("%27", "'"));
                title_label.set_property ("xalign", 0);
                parent_label.set_property ("xalign", 0);
                title_label.ellipsize = Pango.EllipsizeMode.END;
                parent_label.ellipsize = Pango.EllipsizeMode.END;
                title_label.max_width_chars = 30;
                parent_label.max_width_chars = 30;
                box.add (title_label);
                box.add (parent_label);
                content_box.pack_start (box, true, true, 0);
            }

            var details_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            details_box.set_no_show_all (true);
            details_box.hide ();

            // Show a details button
            if (details != null) {
                var details_button = new Gtk.Button.from_icon_name (
                    Utils.check_elementary () ? "help-info-symbolic" : "system-help-symbolic",
                    Gtk.IconSize.SMALL_TOOLBAR
                );
                details_button.relief = Gtk.ReliefStyle.NONE;
                summary_label = new Gtk.Label ("");
                details_button.tooltip_text = _ ("Summary");
                summary_label.wrap = true;
                summary_label.max_width_chars = 30;
                details_box.add (summary_label);

                details_button.clicked.connect (() => {
                    if (!details_visible) {
                        var feed_parser = new FeedParser ();
                        string summary = feed_parser.find_description_from_file (rss_url);
                        summary_label.set_text (summary.length > 0 ? summary : _ ("No summary available."));
                        feed_parser = null;
                        details_box.set_no_show_all (false);
                        details_box.show ();
                        show_all ();
                        details_visible = true;
                    } else {
                        details_box.set_no_show_all (true);
                        details_box.hide ();
                        details_visible = false;
                    }
                });

                details_button.can_focus = false;
                summary_label.can_focus = false;
                details_box.can_focus = false;

                content_box.pack_start (details_button, false, false, 0);
            }


            // Show a subscribe button
            if (subscribe_url != null) {
                subscribe_button = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                subscribe_button.relief = Gtk.ReliefStyle.NONE;
                subscribe_button.tooltip_text = _ ("Subscribe to podcast");

                subscribe_button.clicked.connect (() => {
                    var working_image = new Gtk.Image.from_icon_name (
                        "process-working-symbolic",
                        Gtk.IconSize.SMALL_TOOLBAR
                    );
                    subscribe_button.image = working_image;
                    subscribe_to_podcast (subscribe_url);
                });

                content_box.pack_start (subscribe_button, false, false, 0);
            }
            this.add (content_box);
            this.add (details_box);
        }


        /*
         * Gets the episode
         */
        public Episode get_episode () {
            return episode;
        }

        /*
         * Gets the podcast
         */
        public Podcast get_podcast () {
            return podcast;
        }

        public void set_button_icon (string icon_name) {
            var new_image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.SMALL_TOOLBAR);
            subscribe_button.image = new_image;
        }
    }
}
