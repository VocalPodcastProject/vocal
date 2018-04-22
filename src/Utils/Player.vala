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

using Clutter;
using GLib;
using Gst;
using Gst.PbUtils;

namespace Vocal {
    public class Player : ClutterGst.Playback {

    	private static Player? player = null;
        public static Player? get_default (string[] args) {
            if (player == null) {
                player = new Player(args);
            }
            return player;
        }
    
        public signal void state_changed(Gst.State new_state);
        public signal void additional_plugins_required(Gst.Message message);

        public signal void new_position_available();
        private string tag_string;

        public Episode current_episode;

        private Player(string[]? args) {
        
            bool new_launch = true;

            current_episode = null;
            
            // Check every half-second if the current media is playing, and if it is
            // send a signal that there is a new position available
            GLib.Timeout.add(500, () => {
                
                if(playing)
                    new_position_available();
                if (new_launch && duration > 0.0) {
                    new_position_available();
                    new_launch = false;
                }
                return true;
            });
        }
        
        /*
         *  Returns the total duration of the currently playing media
         */
        public double get_duration () {
            return this.duration;
        }

        /*
         * Returns the current position of the media
         */
        public double get_position () {
            return this.progress;
        }

	    /*
         * Sets the current state to pause
         */
        public void pause () {
            this.playing = false;
        }

	    /*
         * Sets the current state to playing
         */
        public void play () {

            this.playing = true;
        }
        
        /*
         * Seeks backward in the currently playing media n number of seconds
         */
        public void seek_backward (int num_seconds) {
            
            double total_seconds = duration;
            double percentage_of_total_seconds = num_seconds / total_seconds;

            set_position(progress - percentage_of_total_seconds);
        }
        
        /*
         * Seeks forward in the currently playing media n number of seconds
         */
        public void seek_forward (int num_seconds) {
            double total_seconds = duration;
            double percentage_of_total_seconds = num_seconds / total_seconds;

            set_position(progress + percentage_of_total_seconds);
        }
        
        /*
         * Sets the episode that is currently being played
         */
        public void set_episode (Episode episode) {
  
            this.current_episode = episode;
            
            // Set the URI
            this.uri = episode.playback_uri;
            info("Setting playback URI: %s".printf(episode.playback_uri));
            /*
            
            // If it's a video podcast, get the width and height and configure that information
            if(episode.parent.content_type == MediaType.VIDEO) {
	            try {
		            var info = new Gst.PbUtils.Discoverer (10 * Gst.SECOND).discover_uri (this.uri);
		            var video = info.get_video_streams ();
		            if (video.data != null) {
		                var video_info = (Gst.PbUtils.DiscovererVideoInfo)video.data;
		                video_width = video_info.get_width ();
		                video_height = video_info.get_height ();

		                configure_video();

		            }
	            }catch(Error e) {
	            	warning(e.message);
	            }
            }
            */
        }
        
        /*
         * Change the playback rate
         */
        /*
        public void set_playback_rate(double rate) {
            int64 pos = get_position();
            this.seek (2.0,
            Gst.Format.TIME, Gst.SeekFlags.SKIP,
            Gst.SeekType.NONE, pos,
            Gst.SeekType.NONE, duration);
        } 
        */
        
        
        /*
         *  Sets the currently playing media position
         */
        public void set_position (double pos) {
            this.progress = pos;
            new_position_available();
        }

		/*
		 * Sets the current volume
		 */
	    public void set_volume (double val) {
	        this.set_property ("volume", val);
	    }
    }
}
