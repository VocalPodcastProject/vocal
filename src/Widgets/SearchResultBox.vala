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
        public SearchResultBox (Podcast? podcast, Episode? episode, string? details = null, string? subscribe_url = null) {

            this.episode = episode;
            this.podcast = podcast;
            this.details = details;
            this.subscribe_url = subscribe_url;

            this.orientation = Gtk.Orientation.VERTICAL;

            this.margin_top = 6;
            this.margin_bottom = 6;

            // If it's an iTunes URL, find its matching generic RSS URL and set that for the subscribe link
            if (subscribe_url != null && subscribe_url.contains ("itunes.apple")) {
                var itunes = new iTunesProvider ();
                rss_url = itunes.get_rss_from_itunes_url (subscribe_url);
            } else if (subscribe_url != null) {
                rss_url = subscribe_url;
            }

            var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);

            var image = new Gtk.Image();
            ImageCache image_cache = new ImageCache ();
            image_cache.get_image_async.begin (podcast.remote_art_uri, (obj, res) => {
                Gdk.Pixbuf pixbuf = image_cache.get_image_async.end (res);
                if (pixbuf != null) {
                    image.clear ();
                    image.gicon = pixbuf;
                    image.pixel_size = 64;
                    image.overflow = Gtk.Overflow.HIDDEN;
                    image.get_style_context().add_class("squircle");
                    image.show();
                }
            });

            content_box.append(image);

            // Do we only have a podcast?
            if (episode == null) {
                var label = new Gtk.Label (podcast.name.replace ("%27", "'"));
                label.set_property ("xalign", 0);
                label.ellipsize = Pango.EllipsizeMode.END;
                label.max_width_chars = 30;
                content_box.append(label);

            // If not, then we have an episode, which requires more info to be displayed
            } else {
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
                box.hexpand = true;
                box.margin_top = 6;
                box.margin_bottom = 6;
                var title_label = new Gtk.Label (episode.title);
                var parent_label = new Gtk.Label (podcast.name.replace ("%27", "'"));
                title_label.set_property ("xalign", 0);
                parent_label.set_property ("xalign", 0);
                title_label.ellipsize = Pango.EllipsizeMode.END;
                parent_label.ellipsize = Pango.EllipsizeMode.END;
                title_label.max_width_chars = 30;
                parent_label.max_width_chars = 30;
                box.append (title_label);
                box.append (parent_label);
                content_box.append(box);
            }

            var details_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            details_box.hide ();

            // Show a details button
            if (details != null) {
                var details_button = new Gtk.Button.from_icon_name (
                   "system-help-symbolic"    );
                summary_label = new Gtk.Label ("");
                details_button.tooltip_text = _ ("Summary");
                summary_label.wrap = true;
                summary_label.max_width_chars = 30;
                details_box.append (summary_label);

                details_button.clicked.connect (() => {
                    if (!details_visible) {
                        var feed_parser = new FeedParser ();
                        string summary = "";
                        try {
                            summary = feed_parser.find_description_from_file (rss_url);
                        } catch (Error e) {
                            warning (e.message);
                        }
                        summary_label.set_text (summary.length > 0 ? summary : _ ("No summary available."));
                        feed_parser = null;
                        details_box.show ();
                        details_visible = true;
                    } else {
                        details_box.hide ();
                        details_visible = false;
                    }
                });

                details_button.can_focus = false;
                summary_label.can_focus = false;
                details_box.can_focus = false;

                content_box.append(details_button);
            }


            // Show a subscribe button
            if (subscribe_url != null) {
                subscribe_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
                subscribe_button.tooltip_text = _ ("Subscribe to podcast");

                subscribe_button.clicked.connect (() => {
                    subscribe_to_podcast (subscribe_url);
                });

                content_box.append(subscribe_button);
            }
            this.append (content_box);
            this.append (details_box);
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
    }
}
