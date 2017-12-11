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
    public class DownloadDetailBox : Gtk.Box {

        public signal void cancel_requested(Episode e);		// Fired when the cancel button gets clicked

        // Fired upon successful download
        public signal void download_has_completed_successfully(string title, string parent_name, Gdk.Pixbuf pixbuf);

        // Fired when the box is ready for removal (usually when the download completes)
        public signal void ready_for_removal(DownloadDetailBox box);

        public signal void new_percentage_available();		// Fired when a new download percentage is available

        public Gtk.Image	 	image {private get; private set;}
        public Gdk.Pixbuf		image_pixbuf{ get; set; }
        public Gtk.Label 	 	title_label {private get; private set;}
        public Gtk.Label	 	podcast_label {private get; private set;}
        public Gtk.ProgressBar  progress_bar;
        public Gtk.Label 		download_label;

        public double	percentage;
        public int 		secs_elapsed;
        public bool 	download_complete;
        public string 	episode_title;
        public string 	parent_podcast_name;

        private bool signal_has_been_sent;

        string data_output;
        string time_output;
        string outdated_time_output;

        /*
         * Constructor for the download details box, which shows a an episode title, podcast name, and image
         * along with a progress bar indicating progress of the download.
         */
        public DownloadDetailBox (Episode episode, Gdk.Pixbuf pixbuf) {

            string title = episode.title;
            string parent_podcast_name = episode.parent.name;

            image_pixbuf = pixbuf;
            image = new Gtk.Image.from_pixbuf(pixbuf);

            this.episode_title = title;
            this.parent_podcast_name = parent_podcast_name;
            this.orientation = Gtk.Orientation.VERTICAL;

            this.margin = 5;
            this.margin_left = 12;
            this.margin_right = 12;
            this.spacing = 5;

            // Set seconds elapsed to zero
            secs_elapsed = 0;

            // The signal has not been sent. This is to prevent signal from being called twice.
            signal_has_been_sent = false;

            // Create the widgets
            title_label = new Gtk.Label("<b>" + title.replace("%27", "'") + "</b>");
            title_label.set_use_markup(true);
            title_label.set_justify(Gtk.Justification.RIGHT);
            title_label.xalign = 0;
            title_label.max_width_chars = 15;

            podcast_label = new Gtk.Label(parent_podcast_name.replace("%27", "'"));
            podcast_label.set_justify(Gtk.Justification.LEFT);
            podcast_label.xalign = 0;
            podcast_label.max_width_chars = 15;

            var label_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            label_box.add(title_label);
            label_box.add(podcast_label);

            this.image = image;

            var details_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            details_box.add(image);
            details_box.add(label_box);

            var progress_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

            progress_bar = new Gtk.ProgressBar();
            progress_bar.show_text = false;
            progress_bar.expand = true;
            progress_bar.valign = Gtk.Align.CENTER;

            var cancel_button = new Gtk.Button.from_icon_name("process-stop-symbolic", Gtk.IconSize.BUTTON);
            cancel_button.get_style_context().add_class("flat");
            cancel_button.tooltip_text = _("Cancel Download");
            cancel_button.clicked.connect( () => {
                cancel_requested(episode);
            });
            progress_box.add(progress_bar);
            progress_box.add(cancel_button);


            download_label = new Gtk.Label("");
            download_complete = false;
            download_label.xalign = 0;

            this.add(details_box);

            label_box.add(progress_box);
            label_box.add(download_label);


            // While the download isn't complete, keep counting seconds elapsed
            GLib.Timeout.add(1000, () => {
                secs_elapsed += 1;

                if(!download_complete) {
                    return true;
                } else {
                    return false;
                }
            });

            // Periodically update the time on the label
            GLib.Timeout.add(1000, () => {

                outdated_time_output = time_output;

                if(!download_complete) {
                    return true;
                } else {
                    return false;
                }
            });

        }


          /*
         * Sets download progress information when download progress has occurred
         */
        public void download_delegate(int64 current_num_bytes, int64 total_num_bytes) {

            if(current_num_bytes == total_num_bytes && !signal_has_been_sent) {
                // Set percentage to 100% and call new_percentage_available so the launcher progress
                // bar will see the completed value
                this.percentage = 1.0;
                new_percentage_available();
                download_has_completed_successfully(episode_title, parent_podcast_name, image_pixbuf);
                ready_for_removal(this);
                signal_has_been_sent = true;
                return;
            }

            double percentage = ((double)current_num_bytes / (double)total_num_bytes);
            this.percentage = percentage;
            double MB_downloaded = (double)current_num_bytes / 1000000;
            double MB_total = (double)total_num_bytes / 1000000;
            double MB_remaining = (MB_total - MB_downloaded);

            progress_bar.set_fraction(percentage);

            double MBPS = (double) MB_downloaded / secs_elapsed;

            int num_secs_remaining = (int) ( MB_remaining / MBPS);
            int time_val_to_display;
            string units;

            if(num_secs_remaining > 60) {
                time_val_to_display = num_secs_remaining / 60;
                units = ngettext("minute", "minutes", time_val_to_display);
            }
            else {
                time_val_to_display = num_secs_remaining;
                units = ngettext("second", "seconds", time_val_to_display);
            }

            data_output = "%s / %s".printf(GLib.format_size(current_num_bytes), GLib.format_size(total_num_bytes));
            time_output = """, about %d %s remaining""".printf(time_val_to_display, units);

            // When setting the label, always set it to the "outdated" time
            // A separate timer will periodically update the time on the label
            // (this prevents it from being too jarring)

            if(outdated_time_output == null ) {
                outdated_time_output = time_output;
            }

            download_label.set_markup(data_output + outdated_time_output);

            new_percentage_available();
        }
    }
}
