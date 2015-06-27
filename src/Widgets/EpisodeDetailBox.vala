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


namespace Vocal {
    public class EpisodeDetailBox : Gtk.Box {

		// Fired when the streaming/play button gets clicked
        public signal void streaming_button_clicked(int index, int box_index);

        private bool unplayed;
        private bool played;
        private bool now_playing;
    
        public Episode episode;
        public int     index;
        public int     box_index;
        public int 	   top_box_width;
    
        private Gtk.Box     top_box;
        private Gtk.Label   title_label;
        private Gtk.Label   release_label;
        private Gtk.Box     unplayed_box;
        private Gtk.Box     download_box;
        private Gtk.Box     streaming_box;
        private Gtk.Image   unplayed_image;
        private Gtk.Image   now_playing_image;
        public  Gtk.Button  download_button;
        public  Gtk.Button  streaming_button;
        private Gtk.Label description_label;

		/*
		 * Creates a new episode detail box given an episode, and index, a box_index (corresponding
		 * index number for this box in the list in the side pane), and whether Vocal is running
		 * in elementary (determines the icons).
		 */  
        public EpisodeDetailBox(Episode episode, int index, int box_index, bool on_elementary) {
            this.episode = episode;
            this.index = index;
            this.box_index = box_index;
            this.top_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            pack_start(top_box, false, false, 0);
            
            this.orientation = Gtk.Orientation.VERTICAL;
            this.set_size_request(100, 25);
        
            this.homogeneous = false;
            this.border_width = 5;

            unplayed = false;
            played = false;
            now_playing = false;
            
            string location_image = null;
            string streaming_image = "media-playback-start-symbolic";
            string unplayed = null;
            
            unplayed_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            unplayed_box.set_size_request(25, 25);
            
            download_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            download_box.set_size_request(25, 25);

            streaming_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            streaming_box.set_size_request(25, 25);

            // Create the now playing image, but don't actually use it anywhere yet
            now_playing_image = new Gtk.Image.from_icon_name("starred-symbolic", Gtk.IconSize.BUTTON);
            now_playing_image.has_tooltip = true;
            now_playing_image.tooltip_text = _("This episode is currently being played");
            
            // Determine whether or not the episode has been played
            if(episode.status == EpisodeStatus.UNPLAYED) {
                unplayed = "mail-unread";
                this.unplayed = true;
            }
            
            // Determine whether or not the episode has been downloaded
            if(episode.current_download_status != DownloadStatus.DOWNLOADED) {
                if(on_elementary)
                    location_image = "browser-download-symbolic";
                else
                    location_image = "document-save-symbolic";
                streaming_image =  "network-wireless-signal-excellent-symbolic";
            }
            
            // If the episode is unplayed, show an unread icon
            if(unplayed != null) {
                unplayed_image = new Gtk.Image.from_icon_name(unplayed, Gtk.IconSize.BUTTON);
                unplayed_box.pack_start(unplayed_image, false, false, 0);
            }

            // Set up the streaming button
            streaming_button = new Gtk.Button.from_icon_name(streaming_image, Gtk.IconSize.BUTTON);
            streaming_button.expand = false;
            streaming_button.relief = Gtk.ReliefStyle.NONE;
            streaming_button.has_tooltip = true;
            if(episode.current_download_status == DownloadStatus.DOWNLOADED)
                streaming_button.tooltip_text = _("Play");
            else
                streaming_button.tooltip_text = _("Stream Episode");

            // Set up to fire a signal when clicked
            streaming_button.clicked.connect(() => {
                streaming_button_clicked(index, box_index);
            });

            streaming_box.pack_start(streaming_button, false, false, 0);

            
            // If the episode has not been downloaded, show a download button
            if(location_image != null) {
                download_button = new Gtk.Button.from_icon_name(location_image, Gtk.IconSize.BUTTON);
                download_button.expand = false;
                download_button.relief = Gtk.ReliefStyle.NONE;
                download_button.has_tooltip = true;
                download_button.tooltip_text = _("Download Episode");
                download_box.pack_start(download_button, false, false, 0);
            }
            
            top_box.pack_start(unplayed_box, false, false, 0);
                
            // Set up the title and details labels    
            var label_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            label_box.margin = 0;
            title_label = new Gtk.Label("<b>%s</b>".printf(GLib.Markup.escape_text(episode.title.replace("%27", "'").replace("&amp;", "&"))));
            title_label.set_use_markup(true);
            title_label.xalign = 0;
            title_label.justify = Gtk.Justification.LEFT;
            title_label.wrap = true;
            title_label.margin_left = 5;
            title_label.margin_right = 5;
            label_box.pack_start(title_label, true, true, 0);
            if(episode.datetime_released != null) {
                release_label = new Gtk.Label(episode.datetime_released.format(" %x"));
            } else {
                release_label = new Gtk.Label(episode.date_released);
            }
            release_label.xalign = 0;
            release_label.justify = Gtk.Justification.LEFT;
            label_box.expand = false;
            
            label_box.pack_start(release_label, true, true, 0);
            top_box.pack_start(label_box, true, true, 0);
            
            top_box.pack_end(download_box, false, true, 0);
            top_box.pack_end(streaming_box, false, true, 0);

            if(episode.current_download_status == DownloadStatus.DOWNLOADED)
                hide_download_button();

            var spacer = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            spacer.margin_bottom = 0;
            pack_end(spacer);
            
            top_box_width = top_box.width_request;
            
            string text = Utils.html_to_markup(episode.description).replace("\n", " ");

            description_label = new Gtk.Label(text);
            description_label.justify = Gtk.Justification.LEFT;
            description_label.set_use_markup(true);
            description_label.set_ellipsize(Pango.EllipsizeMode.END);
            description_label.lines = 5;
            description_label.max_width_chars = 10;
            description_label.single_line_mode = true;

            description_label.margin = 30;
            description_label.margin_top = 15;
            description_label.margin_bottom = 10;

            description_label.xalign = 0;
            
            pack_end(description_label);
        }

        /*
         * Removes the now playing image from the box
         */
        public void clear_now_playing() {
            if(now_playing) {
                unplayed_box.remove(now_playing_image);
                now_playing = false;
            }
        }
        
        /*
         * Hides the episode's details
         */
        public void hide_details() {
            description_label.set_no_show_all(true);
            description_label.hide();
        }
        
        /*
         * Removes the download button from the box
         */
        public void hide_download_button() {
            download_button.set_no_show_all(true);
            download_button.hide();
            show_all();
        }
        
        /*
         * Hides the streaming/playback button
         */
        public void hide_playback_button() {
            streaming_button.set_no_show_all(true);
            streaming_button.hide();
        }
        
        /*
         * Mark this box as now playing (shows a special image on the left side of the box)
         */
        public void mark_as_now_playing() {

            if(unplayed) {
                unplayed_box.remove(unplayed_image);
                unplayed = false;
            }

            if(now_playing)
                return;

            // It's possible that now_playing_image pointed to the unplayed icon before,
            // so set it to match the icon for now playing

            now_playing_image.icon_name = "starred-symbolic";

            unplayed_box.pack_start(now_playing_image, false, false, 0);
            now_playing = true;

        }
        
        /*
         * Sets the episode's status and removes the unplayed image
         */
        public void mark_as_played() {
            if(unplayed) {
                unplayed_box.remove(unplayed_image);
                unplayed = false;
            }
            show_all();
        }

		/*
		 * Sets the episode's status and shows the unplayed image
		 */
        public void mark_as_unplayed() {

            if(!unplayed) {
                unplayed = true;

                if(now_playing) {
                    unplayed_box.remove(now_playing_image);
                    now_playing = false;
                }

                unplayed_image = new Gtk.Image.from_icon_name("mail-unread", Gtk.IconSize.BUTTON);
                unplayed_box.pack_start(unplayed_image, false, false, 0);

                show_all();
            }
        }

        /*
         * Shows the episode's details
         */
        public void show_details() {
            description_label.set_no_show_all(false);
            description_label.show();
        }
        
        
        /*
         * Shows the download button
         */
        public void show_download_button() {

            download_button.set_no_show_all(false);
            download_button.show();
        }
		
		/*
		 * Shows the play/streaming button
		 */
        public void show_playback_button() {
            string streaming_image;
            if(episode.current_download_status == DownloadStatus.DOWNLOADED) {
                streaming_image =  "media-playback-start-symbolic";
            } else {
                streaming_image =  "network-wireless-signal-excellent-symbolic";
            }

            Gtk.Image image = new Gtk.Image.from_icon_name(streaming_image, Gtk.IconSize.BUTTON);
            streaming_button.set_image(image);

             if(episode.current_download_status == DownloadStatus.DOWNLOADED) {
                streaming_button.tooltip_text = _("Play");

            } else {
                streaming_button.tooltip_text = _("Stream Episode");
            }

            streaming_button.set_no_show_all(false);
            streaming_button.show();
        }
    }
}
