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
    public class PlaybackBox : Gtk.HBox {

        public signal void scale_changed ();        // Fired when the scale changes (when the user seeks position)

        public Gtk.Label episode_label;
        public Gtk.Label podcast_label;
        public Gtk.Image artwork_button;
        private Gtk.ProgressBar progress_bar;
        private Gtk.Scale scale;
        private Gtk.Grid scale_grid;
        private Gtk.Label left_time;
        private Gtk.Label right_time;

        /*
         * Default constructor for a PlaybackBox
         */
        public PlaybackBox () {

            this.get_style_context ().add_class ("seek-bar");
            
            this.halign = Gtk.Align.START;

            this.width_request = 300;
            
            // Create the show notes button
            if (Utils.check_elementary ()) {
                artwork_button = new Gtk.Image.from_icon_name (
                    "help-info-symbolic",
                    Gtk.IconSize.SMALL_TOOLBAR
                );
            } else {
                artwork_button = new Gtk.Image.from_icon_name (
                    "dialog-information-symbolic",
                    Gtk.IconSize.SMALL_TOOLBAR
                );
            }
            artwork_button.tooltip_text = _ ("View show notes");
            artwork_button.valign = Gtk.Align.CENTER;
            artwork_button.valign = Gtk.Align.START;
            
            this.episode_label = new Gtk.Label ("");
            this.episode_label.set_ellipsize (Pango.EllipsizeMode.END);
            this.episode_label.xalign = 0.0f;
            this.episode_label.get_style_context ().add_class ("h3");
            this.episode_label.width_chars = 10;
            
            this.podcast_label = new Gtk.Label ("");
            this.podcast_label.set_ellipsize (Pango.EllipsizeMode.END);
            this.podcast_label.xalign = 0.0f;
            podcast_label.width_chars = 10;
            
            this.progress_bar = new Gtk.ProgressBar ();

            scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1);
            scale.set_value (0.0);
            scale.hexpand = true;
            scale.draw_value = false;
            scale.get_style_context ().add_class ("seekbar");
            left_time = new Gtk.Label ("0:00");
            right_time = new Gtk.Label ("0:00");
            left_time.width_chars = 6;
            right_time.width_chars = 6;

            scale.change_value.connect (on_slide);

            // Create the scale, and attach the time labels to the appropriate sides

            scale_grid = new Gtk.Grid ();
            scale_grid.valign = Gtk.Align.CENTER;

            left_time.margin_right = right_time.margin_left = 3;

            scale_grid.attach (left_time, 0, 0, 1, 1);
            scale_grid.attach (scale, 1, 0, 1, 1);
            scale_grid.attach (right_time, 2, 0, 1, 1);

            this.hexpand = false;

            // Add the components to the box
            
            var label_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            label_box.add (episode_label);
            label_box.add (podcast_label);
            label_box.valign = Gtk.Align.CENTER;
            label_box.halign = Gtk.Align.START;
            
            this.add (artwork_button);
            this.add (label_box);
            this.add (scale_grid);
        }

        public override void get_preferred_width (out int minimum_width, out int natural_width) {
            base.get_preferred_width (out minimum_width, out natural_width);
            minimum_width = 300;
            if (natural_width < 600) {
                natural_width = 600;
            }
        }

        /*
         * Returns the percentage that the progress bar has been filled
         */
        public double get_progress_bar_fill () {
            return scale.get_value ();
        }

        /*
         * Called when the user slides the slider in order to change position in the stream
         */
        private bool on_slide (ScrollType scroll, double new_value) {
            scale.set_value (new_value);
            scale_changed ();
            return false;
        }

        /*
         * Sets the information for the current episode
         */
        public void set_info_title (string episode, string podcast_name) {
           	this.episode_label.label = episode;
           	this.podcast_label.label = podcast_name;
        }

        /*
         * Sets the progress information for the current stream to be displayed
         */
        public void set_progress (
            double progress,
            int mins_remaining,
            int secs_remaining,
            int mins_elapsed,
            int secs_elapsed
        ) {

            scale.set_value (progress);

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
            this.left_time.set_no_show_all (false);
            left_time.show ();

            this.right_time.set_no_show_all (false);
            right_time.show ();

            this.scale.set_no_show_all (false);
            scale.show ();
        }
        
        public void show_artwork_button () {
            if (artwork_button != null) {
                artwork_button.set_no_show_all (false);
                artwork_button.show ();
            }
        }

        public void hide_artwork_button () {
            if (artwork_button != null) {
                artwork_button.set_no_show_all (true);
                artwork_button.hide ();
            }
        }
        
        public void set_artwork_button_image (string uri) {
        	artwork_button.clear ();
        	var artwork = GLib.File.new_for_uri (uri);
            var icon = new GLib.FileIcon (artwork);
            artwork_button = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DIALOG);
        	artwork_button.pixel_size = 25;
        }
    }
}
