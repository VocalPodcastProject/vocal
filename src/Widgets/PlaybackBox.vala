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
    class PlaybackBox : Gtk.VBox {
        
        public signal void scale_changed();		// Fired when the scale changes (when the user seeks position)
    
        public Gtk.Label 		info_label;
        private Gtk.ProgressBar progress_bar;
        private Gtk.Scale 		scale;
        private Gtk.Grid 		scale_grid;
        private Gtk.Label 		left_time;
        private Gtk.Label 		right_time;
   
        /*
         * Default constructor for a PlaybackBox
         */
        public PlaybackBox () {
            this.width_request  = 300;
            this.info_label = new Gtk.Label(_("<b>Select an episode to start playing...</b>"));
            this.info_label.set_use_markup(true);
            this.info_label.width_chars = 20;
            this.info_label.set_ellipsize(Pango.EllipsizeMode.END);

            this.progress_bar = new Gtk.ProgressBar();
            
            scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 1000);
            scale.set_value(0.0);
            scale.hexpand = true;
            scale.draw_value = false;
            left_time = new Gtk.Label ("0:00");
            right_time = new Gtk.Label ("0:00");
            
            scale.change_value.connect(on_slide);
                  
            // Create the scale, and attach the time labels to the appropriate sides 
                  
            scale_grid = new Gtk.Grid ();
            
            left_time.margin_right = right_time.margin_left = 3;

            scale_grid.attach (left_time, 0, 0, 1, 1);
            scale_grid.attach (scale, 1, 0, 1, 1);
            scale_grid.attach (right_time, 2, 0, 1, 1);
            
            // Add the components to the box
            this.add(info_label);
            this.add(scale_grid);
        }
        
        /*
         * Returns the percentage that the progress bar has been filled
         */
        public double get_progress_bar_fill() {
            return scale.get_value();
        }
        
        /*
         * Called when the user slides the slider in order to change position in the stream
         */
        private bool on_slide(ScrollType scroll, double new_value) {
            scale.set_value(new_value);
            scale_changed();
            return false;
        }
        
        /*
         * Sets the information for the current episode
         */
        public void set_info_title(string episode, string podcast_name) {
            this.info_label.set_text("<b>" + GLib.Markup.escape_text(episode) + "</b>" + " from " + "<b><i>" + GLib.Markup.escape_text(podcast_name) + "</i></b>");
            this.info_label.set_use_markup(true);
        }
        
        /*
 		 * Sets the message on the info label
 		 */
        public void set_message(string message) {
        
            // Hide the left and right time
            this.left_time.set_no_show_all(true);
            left_time.hide();
            
            this.right_time.set_no_show_all(true);
            right_time.hide();
            
            this.scale.set_no_show_all(true);
            scale.hide();
            
            this.info_label.set_text(message);
            this.info_label.set_use_markup(true);
             
        }
        
		/*
		 * Sets both the message and the percentage
		 */
        public void set_message_and_percentage(string message, double? new_value = -1) {
        
            // Hide the left and right time
            this.left_time.set_no_show_all(true);
            left_time.hide();
            
            this.right_time.set_no_show_all(true);
            right_time.hide();
            
            // Set the message
            this.info_label.set_text(message);
            this.info_label.set_use_markup(true);
            
            // Set the progress percentage
            if(new_value != -1) {
                scale.set_value(new_value);
            }
        }
        
        /*
         * Sets the progress information for the current stream to be displayed
         */
        public void set_progress(double progress, int mins_remaining, int secs_remaining, int mins_elapsed, int secs_elapsed) {
            
            scale.set_value(progress);
            
            // Set the labels on either side of the scale
            if(mins_remaining > 59) {
                int hours_remaining = mins_remaining / 60;
                mins_remaining = mins_remaining % 60;
                right_time.set_text("%02d:%02d:%02d".printf(hours_remaining, mins_remaining, secs_remaining));
            }
            else {
                right_time.set_text("%02d:%02d".printf(mins_remaining, secs_remaining));
            }
            
            if(mins_elapsed > 59) {
                int hours_elapsed = mins_elapsed / 60;
                mins_elapsed = mins_elapsed % 60;
                left_time.set_text("%02d:%02d:%02d".printf(hours_elapsed, mins_elapsed, secs_elapsed));
            }
            else {
                left_time.set_text("%02d:%02d".printf(mins_elapsed, secs_elapsed));
            }
            
            // Show the left and right labels
            this.left_time.set_no_show_all(false);
            left_time.show();
            
            this.right_time.set_no_show_all(false);
            right_time.show();
            
            this.scale.set_no_show_all(false);
            scale.show();
        }
    }
}
