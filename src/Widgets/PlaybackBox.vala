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
    public class PlaybackBox : Gtk.Box {

        public signal void scale_changed ();        // Fired when the scale changes (when the user seeks position)
        public signal void rate_changed(double rate);
        public signal void volume_changed(double vol);
        public signal void position_changed(double pos);
        public signal void remove_episode_from_queue (Episode e);

        public Gtk.Label now_playing;
        public Gtk.Button info;
        private Gtk.Label info_label;
        private Gtk.Scale scale;
        private Gtk.Grid scale_grid;
        private Gtk.Label left_time;
        private Gtk.Label right_time;
        private Gtk.Scale volume_scale;
        public Gtk.Button volume_button;

        public QueueBox queue_box;

        private double rate;
        private int last_secs_elapsed = 0;
        private bool can_update = true;

        /*
         * Default constructor for a PlaybackBox
         */
        public PlaybackBox () {

            this.orientation = Gtk.Orientation.VERTICAL;
            this.halign = Gtk.Align.FILL;
            this.hexpand = true;

            this.get_style_context().add_class("toolbar");

            info = new Gtk.Button.from_icon_name ("dialog-information-symbolic");
            info.tooltip_text = _ ("View the shownotes for this episode or check the queue");

            info_label = new Gtk.Label("Description");

            var info_popover = new Gtk.Popover();
            info_popover.set_parent(info);
            info_popover.set_autohide(true);
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            info_box.append(info_label);
            info_popover.set_child(info_box);

            info.clicked.connect(() => {
                info_popover.popup();
            });

            rate = 1.0;
            var rate_button = new Gtk.Button.with_label ("1x");
            rate_button.clicked.connect( () => {
                if (rate == 1.0) {
                    rate = 1.25;
                    rate_button.label = "1.25x";
                    rate_changed (1.25);
                } else if (rate == 1.25) {
                    rate = 1.5;
                    rate_button.label = "1.5x";
                    rate_changed (1.5);
                } else if (rate == 1.5) {
                    rate = 2.0;
                    rate_button.label = "2x";
                    rate_changed (2.0);
                } else {
                    rate = 1.0;
                    rate_button.label = "1x";
                    rate_changed(1.0);
                }
            });

            now_playing = new Gtk.Label("<b>Episode Title</b> from <b>Podcast Name</b>");
            now_playing.use_markup = true;
            now_playing.margin_top = 12;

            scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1);
            scale.set_value (0.0);
            scale.hexpand = true;
            scale.draw_value = false;
            scale.width_request = 75;
            scale.get_style_context ().add_class ("seekbar");
            scale.halign = Gtk.Align.FILL;

            left_time = new Gtk.Label ("0:00");
            right_time = new Gtk.Label ("0:00");
            left_time.width_chars = 6;
            right_time.width_chars = 6;

            // Create the scale, and attach the time labels to the appropriate sides

            scale_grid = new Gtk.Grid ();
            scale_grid.valign = Gtk.Align.CENTER;

            left_time.margin_end = right_time.margin_start = 3;

            scale_grid.attach (left_time, 0, 0, 1, 1);
            scale_grid.attach (scale, 1, 0, 1, 1);
            scale_grid.attach (right_time, 2, 0, 1, 1);

            this.hexpand = false;

            scale.change_value.connect((scroll, new_value) => {
                position_changed(new_value);
                return true;
            });

            // Add the components to the box

            volume_button = new Gtk.Button.from_icon_name ("audio-volume-high-symbolic");
            volume_button.margin_end = 12;

            var volume_popover = new Gtk.Popover();
            volume_popover.set_parent(volume_button);
            volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.VERTICAL, 0, 1, 0.1);
            volume_scale.height_request = 150;
            volume_scale.set_value (0.0);
            volume_scale.hexpand = true;
            volume_scale.draw_value = false;
            volume_scale.inverted = true;
            volume_popover.set_child(volume_scale);

            volume_scale.value_changed.connect(() => {
                volume_changed(volume_scale.get_value ());
            });

            volume_button.clicked.connect(() => {
                volume_popover.popup();
            });

            var queue_button = new Gtk.Button.from_icon_name("view-list-symbolic");
            var queue_popover = new Gtk.Popover();
            queue_popover.set_parent(queue_button);
            queue_box = new QueueBox();
            queue_box.remove_episode.connect((e) => {
               remove_episode_from_queue(e);
            });
            queue_popover.set_child(queue_box);
            queue_button.clicked.connect(() => {
                queue_popover.popup ();
            });

            this.append(now_playing);
            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            hbox.append(info);
            hbox.append(rate_button);
            hbox.append(scale_grid);
            hbox.append(volume_button);
            hbox.append(queue_button);
            this.append(hbox);

            hide_info_title();
        }


        /*
         * Returns the percentage that the progress bar has been filled
         */
        public double get_progress_bar_fill () {
            return scale.get_value ();
        }

        /*
         * Sets the information for the current episode
         */
        public void set_info_title (string episode, string podcast_name) {
           	now_playing.set_text("<b>%s</b> from <b>%s</b>".printf (episode, podcast_name));
           	now_playing.use_markup = true;
           	show_info_title ();
        }

        public void set_description(string description) {
            info_label.set_text (description);
        }

        public void set_position (uint64 position, uint64 duration) {

            if (can_update) {

                this.scale.set_value((double)((double)position / (double)duration));

                int total_secs_remaining = (int) ((duration - position) / 1000000000);
                int total_secs_elapsed = (int) ((position) / 1000000000);

                if (total_secs_elapsed == last_secs_elapsed) {
                    last_secs_elapsed = total_secs_elapsed;
                    return;
                }

                last_secs_elapsed = total_secs_elapsed;

                int secs_remaining = total_secs_remaining % 60;
                int secs_elapsed = total_secs_elapsed % 60;

                int mins_remaining = total_secs_remaining / 60;
                int mins_elapsed = total_secs_elapsed / 60;

                // Set the labels on either side of the scale
                if (mins_remaining > 59) {
                    int hours_remaining = mins_remaining / 60;
                    mins_remaining = mins_remaining % 60;
                    right_time.set_text ("%02d:%02d:%02d".printf (hours_remaining, mins_remaining, secs_remaining));
                }
                else {
                    right_time.set_text ("%02d:%02d".printf (mins_remaining, secs_remaining));
                }

                if (mins_elapsed > 59) {
                    int hours_elapsed = mins_elapsed / 60;
                    mins_elapsed = mins_elapsed % 60;
                    left_time.set_text ("%02d:%02d:%02d".printf (hours_elapsed, mins_elapsed, secs_elapsed));
                }
                else {
                    left_time.set_text ("%02d:%02d".printf (mins_elapsed, secs_elapsed));
                }

                // Show the left and right labels
                this.left_time.visible = false;
                left_time.show ();

                this.right_time.visible = false;
                right_time.show ();

                this.scale.visible = false;
                scale.show ();
            }
        }

        public void hide_info_title() {
            now_playing.hide();
        }

        public void show_info_title() {
            now_playing.show();
        }

        public void set_volume (double val) {
            volume_scale.set_value(val);
        }
    }
}
