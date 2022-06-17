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

    public class CoverArt : Gtk.Box {

        private const int COVER_SIZE = 170;

        public Gtk.Image image;                // The actual coverart image
        private Gtk.Overlay count_overlay;     // Overlays the count on top of the banner
        private Gtk.Label count_label;         // The label that stores the unplayed count
        private Gtk.Label podcast_name_label;  // The label that show the name of the podcast
                                               // (if it is enabled in the settings)

        public Podcast podcast;                // Refers to the podcast this coverart represents


        /*
         * Constructor for CoverArt given an image path and a podcast
         */
        public CoverArt (Podcast podcast, bool? show_mimetype = false) {

            this.podcast = podcast;
            this.margin_top = 10;
            this.margin_bottom = 10;
            this.margin_start = 10;
            this.margin_end = 10;
            this.orientation = Gtk.Orientation.VERTICAL;

            image = new Gtk.Image();
            count_overlay = new Gtk.Overlay ();

            image.overflow = Gtk.Overflow.HIDDEN;
            count_overlay.set_child (image);

            // Create a label to display the number of new episodes
            count_label = new Gtk.Label ("");
            count_label.use_markup = true;
            count_label.halign = Gtk.Align.END;
            count_label.valign = Gtk.Align.START;
            count_label.width_chars = 2;
            count_label.xalign = 0.50f;
            count_label.margin_top = 3;
            count_label.margin_end = 3;

            // Add a tooltip
            this.tooltip_text = podcast.name.replace ("%27", "'");

            // Set up the overlays

            count_overlay.add_overlay (count_label);
            count_label.get_style_context().add_class("badge");
            this.append(count_overlay);



            if(VocalSettings.get_default_instance().theme_preference == "dark") {
                count_label.get_style_context().add_class("badge-dark");
            } else {
               count_label.get_style_context().add_class("badge-light");
            }



            VocalSettings.get_default_instance().changed.connect((key) => {
                if(key == "theme-preference") {
                    if(VocalSettings.get_default_instance().theme_preference == "dark") {
                        count_label.get_style_context().remove_class("badge-light");
                        count_label.get_style_context().add_class("badge-dark");
                    } else {
                        count_label.get_style_context().remove_class("badge-dark");
                        count_label.get_style_context().add_class("badge-light");
                    }
                } else if (key == "show-name-label") {
                    if (VocalSettings.get_default_instance ().show_name_label) {
                        image.get_style_context().remove_class("squircle");
                        image.get_style_context().add_class("squircle-top");
                        podcast_name_label.visible = true;
                    } else {
                        image.get_style_context().remove_class("squircle-top");
                        image.get_style_context().add_class("squircle");
                        podcast_name_label.visible = false;
                    }
                }
            });


            this.valign = Align.START;
            string podcast_name = GLib.Uri.unescape_string (podcast.name);
            if (podcast_name == null) {
                podcast_name = podcast.name.replace ("%25", "%");
            }
            podcast_name = podcast_name.replace ("&", """&amp;""");

            podcast_name_label = new Gtk.Label ("<b>" + podcast_name + "</b>");
            podcast_name_label.wrap = true;
            podcast_name_label.use_markup = true;
            podcast_name_label.max_width_chars = 15;
            this.append (podcast_name_label);

            if (!VocalSettings.get_default_instance ().show_name_label) {
                image.get_style_context().add_class("squircle");
                podcast_name_label.visible = false;
            } else {
                image.get_style_context().add_class("squircle-top");
            }

            load_art.begin((obj, res) => {
                load_art.end(res);
            });

        }

        /*
         * Creates a pixbuf given an InputStream
         */
        public Gdk.Pixbuf? create_cover_image (InputStream input_stream) {
            try {
                var cover_image = new Gdk.Pixbuf.from_stream (input_stream);

                if (cover_image.height == cover_image.width)
                    cover_image = cover_image.scale_simple (COVER_SIZE, COVER_SIZE, Gdk.InterpType.BILINEAR);

                if (cover_image.height > cover_image.width) {

                    int new_height = COVER_SIZE * cover_image.height / cover_image.width;
                    int new_width = COVER_SIZE;
                    int offset = (new_height - new_width) / 2;

                    cover_image = new Gdk.Pixbuf.subpixbuf (
                        cover_image.scale_simple (new_width, new_height, Gdk.InterpType.BILINEAR),
                        0,
                        offset,
                        COVER_SIZE,
                        COVER_SIZE
                    );

                } else if (cover_image.height < cover_image.width) {

                    int new_height = COVER_SIZE;
                    int new_width = COVER_SIZE * cover_image.width / cover_image.height;
                    int offset = (new_width - new_height) / 2;

                    cover_image = new Gdk.Pixbuf.subpixbuf (
                        cover_image.scale_simple (new_width, new_height, Gdk.InterpType.BILINEAR),
                        offset,
                        0,
                        COVER_SIZE,
                        COVER_SIZE
                    );
                }

                return cover_image;
            }catch (Error e) {
                warning (e.message);
                return null;
            }
        }

        private async void load_art() {

            GLib.Idle.add(load_art.callback);

            ImageCache image_cache = new ImageCache ();
            image_cache.get_image_async.begin(podcast.remote_art_uri, (obj,res) => {
                var pixbuf = image_cache.get_image_async.end(res);
                if (pixbuf != null) {
                    image.clear ();
                    image.gicon = pixbuf;
                    image.pixel_size = 200;
                    image.show();
                }
            });
            yield;
        }

        /*
         * Hides the banner and the count
         */
        public void hide_count () {
            if (count_label != null) {
                count_label.hide ();
            }
        }

        /*
         * Sets the banner count
         */
        public void set_count (int count) {
            if (count_label != null) {
                count_label.set_text ("%d".printf (count));
            }
        }

        /*
         * Shows the banner and the count
         */
        public void show_count () {
            if (count_label != null) {
                count_label.show ();
            }
        }


        /*
         * Shows the name label underneath the cover art
         */
        public void show_name_label () {
            if (podcast_name_label != null) {
                podcast_name_label.visible = true;
            }
        }

        /*
         * Hides the name label underneath the cover art
         */
         public void hide_name_label () {
             if (podcast_name_label != null) {
                podcast_name_label.visible = false;
            }
         }
    }
}
