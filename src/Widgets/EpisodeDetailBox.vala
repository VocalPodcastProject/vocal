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
    public class EpisodeDetailBox : Gtk.Box {

        // Fired when the streaming/play button gets clicked
        public signal void streaming_button_clicked ();

        private bool unplayed;
        private bool played;
        private bool now_playing;

        public Episode episode;
        public int top_box_width;

        private Gtk.Box top_box;
        private Gtk.Label title_label;
        private Gtk.Label release_label;
        private Gtk.Box unplayed_box;
        private Gtk.Box download_box;
        private Gtk.Box streaming_box;
        private Gtk.Image unplayed_image;
        private Gtk.Image now_playing_image;
        public Gtk.Button download_button;
        public Gtk.Button streaming_button;
        private Gtk.Label description_label;

        /*
         * Creates a new episode detail box given an episode.
         */
        public EpisodeDetailBox (Episode episode, Vocal.Application controller, bool new_episodes_view = false) {
            this.episode = episode;
            this.top_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            append (top_box);

            this.orientation = Gtk.Orientation.VERTICAL;
            this.set_size_request (100, 25);
            margin_top = 12;
            margin_bottom = 12;
            margin_start = 12;
            margin_end = 12;

            this.homogeneous = false;

            unplayed = false;
            played = false;
            now_playing = false;

            string location_image = null;
            string streaming_image = "media-playback-start-symbolic";
            string unplayed = null;

            unplayed_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            unplayed_box.set_size_request (25, 25);

            download_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            download_box.set_size_request (25, 25);

            streaming_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            streaming_box.set_size_request (25, 25);

            // Create the now playing image, but don't actually use it anywhere yet
            now_playing_image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic");
            now_playing_image.has_tooltip = true;
            now_playing_image.tooltip_text = _ ("This episode is currently being played");

            // Determine whether or not the episode has been played
            if (episode.status == EpisodeStatus.UNPLAYED) {
                unplayed = "starred-symbolic";
                this.unplayed = true;
            }

            // Determine whether or not the episode has been downloaded
            if (episode.current_download_status != DownloadStatus.DOWNLOADED) {
                location_image = "document-save-symbolic";
                streaming_image = "network-wireless-signal-excellent-symbolic";
            }

            // If the episode is unplayed, show an unread icon
            if (unplayed != null && new_episodes_view == false) {
                unplayed_image = new Gtk.Image.from_icon_name (unplayed);
                unplayed_image.valign = Gtk.Align.START;
                unplayed_box.append (unplayed_image);
            }

            if (new_episodes_view) {
                var image = new Gtk.Image();
                ImageCache image_cache = new ImageCache ();
                image_cache.get_image_async.begin (episode.parent.remote_art_uri, (obj, res) => {
                    Gdk.Pixbuf pixbuf = image_cache.get_image_async.end (res);
                    if (pixbuf != null) {
                        image.clear ();
                        image.gicon = pixbuf;
                        image.show();
                    }
                });
                image.margin_top = 0;
                image.margin_bottom = 0;
                image.margin_end = 12;
                image.pixel_size = 75;
                image.overflow = Gtk.Overflow.HIDDEN;
                image.get_style_context().add_class("squircle");
                unplayed_box.append(image);
            }

            // Set up the streaming button
            streaming_button = new Gtk.Button.from_icon_name (streaming_image);
            streaming_button.has_tooltip = true;
            if (episode.current_download_status == DownloadStatus.DOWNLOADED)
                streaming_button.tooltip_text = _ ("Play");
            else
                streaming_button.tooltip_text = _ ("Stream Episode");

            // Set up to fire a signal when clicked
            streaming_button.clicked.connect (() => {
                streaming_button_clicked ();
            });

            streaming_box.append(streaming_button);


            // If the episode has not been downloaded, show a download button
            if (location_image != null) {
                download_button = new Gtk.Button.from_icon_name (location_image);
                download_button.has_tooltip = true;
                download_button.tooltip_text = _ ("Download Episode");
                download_box.append(download_button);
            }

            top_box.append(unplayed_box);

            // Set up the title and details labels
            var label_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            title_label = new Gtk.Label ("<b>%s</b>".printf (GLib.Markup.escape_text (episode.title.replace ("%27", "'").replace ("&amp;", "&"))));  // vala-lint=line-length
            title_label.set_use_markup (true);
            title_label.halign = Gtk.Align.START;
            title_label.hexpand = true;
            title_label.wrap = true;
            label_box.append(title_label);

            if (new_episodes_view) {
                var name_label = new Gtk.Label (episode.parent.name);
                name_label.halign = Gtk.Align.START;
                name_label.justify = Gtk.Justification.LEFT;
                name_label.wrap = true;
                label_box.append(name_label);
            }

            if (episode.datetime_released != null) {
                release_label = new Gtk.Label (episode.datetime_released.format ("%x"));
            } else {
                release_label = new Gtk.Label (episode.date_released);
            }
            release_label.halign = Gtk.Align.START;
            release_label.justify = Gtk.Justification.LEFT;

            label_box.append(release_label);
            top_box.append(label_box);

            if (episode.current_download_status == DownloadStatus.DOWNLOADED)
                hide_download_button ();

            top_box_width = top_box.width_request;

            string text = Utils.html_to_markup (episode.description);

            // Remove repeated whitespace from description before adding to label.
            try {
                Regex condense_spaces = new Regex ("\\s{2,}");
                text = condense_spaces.replace (text, -1, 0, " ").strip ();
            } catch (Error e) {
                warning (e.message);
            }

            description_label = new Gtk.Label (text != " (null)" ? text : _ ("No description available."));
            description_label.justify = Gtk.Justification.LEFT;
            description_label.set_use_markup (true);
            description_label.set_ellipsize (Pango.EllipsizeMode.END);
            description_label.lines = 2;
            description_label.max_width_chars = 10;
            description_label.single_line_mode = true;

            description_label.set ("xalign", 0);

            label_box.append (description_label);

            // set the CSS
            this.get_style_context ().add_class ("episode_detail_box");
        }

        /*
         * Removes the now playing image from the box
         */
        public void clear_now_playing () {
            if (now_playing) {
                unplayed_box.remove (now_playing_image);
                now_playing = false;
            }
        }

        /*
         * Removes the download button from the box
         */
        public void hide_download_button () {
            if (download_button != null) {
                download_button.hide ();
            }
        }

        /*
         * Hides the streaming/playback button
         */
        public void hide_playback_button () {
            streaming_button.hide ();
        }

        /*
         * Mark this box as now playing (shows a special image on the left side of the box)
         */
        public void mark_as_now_playing () {

            if (unplayed) {
                unplayed_box.remove (unplayed_image);
                unplayed = false;
            }

            if (now_playing)
                return;

            // It's possible that now_playing_image pointed to the unplayed icon before,
            // so set it to match the icon for now playing

            now_playing_image.icon_name = "media-playback-start-symbolic";

            unplayed_box.append(now_playing_image);
            now_playing = true;

        }

        /*
         * Sets the episode's status and removes the unplayed image
         */
        public void mark_as_played () {
            if (unplayed) {
                unplayed_box.remove (unplayed_image);
                unplayed = false;
            }
        }

        /*
         * Sets the episode's status and shows the unplayed image
         */
        public void mark_as_unplayed () {

            if (!unplayed) {
                unplayed = true;

                if (now_playing) {
                    unplayed_box.remove (now_playing_image);
                    now_playing = false;
                }

                unplayed_image = new Gtk.Image.from_icon_name ("starred-symbolic");
                unplayed_box.append(unplayed_image);
                unplayed_image.valign = Gtk.Align.START;
            }
        }

        /*
         * Shows the download button
         */
        public void show_download_button () {
            download_button.show ();
        }

        /*
         * Shows the play/streaming button
         */
        public void show_playback_button () {
            string streaming_image;
            if (episode.current_download_status == DownloadStatus.DOWNLOADED) {
                streaming_image = "media-playback-start-symbolic";
            } else {
                streaming_image = "network-wireless-signal-excellent-symbolic";
            }

            streaming_button.icon_name = streaming_image;

             if (episode.current_download_status == DownloadStatus.DOWNLOADED) {
                streaming_button.tooltip_text = _ ("Play");

            } else {
                streaming_button.tooltip_text = _ ("Stream Episode");
            }

            streaming_button.show ();
        }
    }
}
