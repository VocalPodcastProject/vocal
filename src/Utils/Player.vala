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
    class Player : Actor {

    	private static Player? player = null;
        public static Player? get_default (string[] args) {
            if (player == null)
                player = new Player(args);
            return player;
        }
    
        public signal void state_changed(Gst.State new_state);
        public signal void stream_ended();
        public signal void additional_plugins_required(Gst.Message message);

        public dynamic Gst.Element playbin;
        public Clutter.Texture video;
        public uint video_width;
        public uint video_height;

        private MainLoop loop = new MainLoop ();
        public signal void new_position_available();
        private string tag_string;       
        
        public bool is_currently_playing;
        
        public Gst.State current_state;
        
        public Episode current_episode;
        
        private Player(string[]? args) {

        	/*	NOTE:
				This code is heavily influenced by the Audience source code, written by Tom Beckmann <tomjonabc@gmail.com>
                and Corentin Noël <corentin@elementaryos.org>, available at https://launchpad.net/audience.
        	 */

            // Set up the Clutter actor
            video = new Clutter.Texture ();

            // Set width and height to 0 initially
            video_width = 0;
            video_height = 0;

            dynamic Gst.Element video_sink = Gst.ElementFactory.make ("cluttersink", "source");

            video_sink.texture = video;

            playbin = Gst.ElementFactory.make ("playbin", "playbin");
            playbin.video_sink = video_sink;

            add_child(video);

            current_episode = null;

            is_currently_playing = false;
            
            // Check every half-second if the current media is playing, and if it is
            // send a signal that there is a new position available
            GLib.Timeout.add(500, () => {
                if(current_state == Gst.State.PLAYING)
                    new_position_available();
                return true;
            });
                   
        }
        
        /*
         * Bus callback
         */
        private bool bus_callback (Gst.Bus bus, Gst.Message message) {
        
            switch (message.type) {
                case MessageType.ERROR:
                    GLib.Error err;
                    string debug;
                    message.parse_error (out err, out debug);

                    loop.quit ();
                    break;
                case Gst.MessageType.ELEMENT:
                    if(message.get_structure() != null && Gst.PbUtils.is_missing_plugin_message(message)) {
                        additional_plugins_required(message);
                    }
                    break;
                case MessageType.EOS:
                    stdout.printf ("end of stream\n");
                    is_currently_playing = false;
                    stream_ended();
                    break;
                case MessageType.STATE_CHANGED:
                    Gst.State oldstate;
                    Gst.State newstate;
                    Gst.State pending;
                    
                    
                    message.parse_state_changed (out oldstate, out newstate,
                                                 out pending);
                                                 
                    current_state = newstate;
                    state_changed(newstate);

                    break;
                case MessageType.TAG:
                    Gst.TagList tag_list;
                    message.parse_tag (out tag_list);
                    tag_list.foreach ((Gst.TagForeachFunc) foreach_tag);
                    break;
                default:
                    break;
                }

            return true;
        }
        
        /*
		 * Reconfigures the video (width, positions, etc.) as needed
		 */
        public void configure_video() {

        	// Make sure the video has both a known width and height at this point
        	if(video_width > 0 && video_height > 0) {

	            // Get the stage
            	var stage = get_stage ();

            	// Calculate the videos aspect ratio

		        var aspect = (float)stage.width / (float)video_width < (float)stage.height / (float)video_height ?
                	(float)stage.width / (float)video_width : (float)stage.height / (float)video_height;

	            video.width  = video_width * aspect;
	            video.height = video_height * aspect;
	            video.x = (stage.width  - video.width)  / 2;
	            video.y = (stage.height - video.height) / 2;
            }
        }
        
        /*
         * Iterates through a list of tags and sets matching properties
         */
        private void foreach_tag (Gst.TagList list, string tag) {
            switch (tag) {
            case "title":
                list.get_string (tag, out tag_string);
                break;
            default:
                break;
            }
        }
        
        /*
         *  Returns the total duration of the currently playing media
         */
        public int64 get_duration () {
            int64 rv = (int64)0;
            Gst.Format f = Gst.Format.TIME;
            
            playbin.query_duration (f, out rv);
            
            return rv;
        }
        
        /*
         * Returns the current position of the media
         */
        public int64 get_position () {
            int64 rv = (int64)0;
            Gst.Format f = Gst.Format.TIME;
            
            playbin.query_position (f, out rv);
            
            return rv;
        }
/*

        public string get_track_name() {
            return tag_string;
        }

        public double get_volume () {
	        var val = GLib.Value (typeof(double));
	        playbin.get_property ("volume", ref val);
	        return (double)val;
	    }
*/
	    
	    /*
         * Sets the current state to pause
         */
        public void pause () {
            set_state (Gst.State.PAUSED);
            is_currently_playing = false;
        }
	    
	    /*
         * Sets the current state to playing
         */
        public void play () {

            set_state (Gst.State.PLAYING);

            is_currently_playing = true;
        }
        
        /*
         * Seeks backward in the currently playing media n number of seconds
         */
        public void seek_backward (int num_seconds) {
            Gst.State previous = current_state;
            int64 mil = (int64)num_seconds * 1000000000;
            int64 current = this.get_position();
            int64 new_position = current - mil;
            this.set_position(new_position);
            
            new_position_available();
            
            // If it was paused before, pause it again
            set_state(previous);
        }
        
        /*
         * Seeks forward in the currently playing media n number of seconds
         */
        public void seek_forward (int num_seconds) {
            Gst.State previous = current_state;
            int64 mil = (int64)num_seconds * 1000000000;
            int64 current = this.get_position();
            int64 new_position = current + mil;
            this.set_position(new_position);
            
            new_position_available();
            
            // If it was paused before, pause it again
            set_state(previous);
        }
        
        /*
         * Sets the episode that is currently being played
         */
        public void set_episode (Episode episode) {

            // Set the previous state to ready
            set_state(Gst.State.PAUSED);
            set_state(Gst.State.READY);
            
            this.current_episode = episode;
            
            // Set playbin to null
            set_state(Gst.State.NULL);
            
            // Set the URI
            playbin.uri = episode.playback_uri;
            info("Setting URI: %s".printf(episode.playback_uri));
            
            // If it's a video podcast, get the width and height and configure that information
            if(episode.parent.content_type == MediaType.VIDEO) {
	            try {
		            var info = new Gst.PbUtils.Discoverer (10 * Gst.SECOND).discover_uri (playbin.uri);
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
    
            Gst.Bus bus = playbin.get_bus ();
            bus.add_watch (0, bus_callback);
        }
        
        /*
         * Change the playback rate
         */
        public void set_playback_rate(double rate) {
            int64 pos = get_position();
            playbin.seek (2.0,
            Gst.Format.TIME, Gst.SeekFlags.SKIP,
            Gst.SeekType.NONE, pos,
            Gst.SeekType.NONE, get_duration ());
        } 
        
        /*
         *  Sets the currently playing media position
         */
        public void set_position (int64 pos) {

        	// Slowly dial the volume back (should help avoid the crappy choppy sound when streaming)
        	for(double i = 0.1; i <= 1; i += 0.1) {
        		set_volume(1.0 - i);
        		Thread.usleep(50000);
        	}
            
            playbin.seek (1.0,
            Gst.Format.TIME, Gst.SeekFlags.FLUSH,
            Gst.SeekType.SET, pos,
            Gst.SeekType.NONE, get_duration ());

                       
            // Let this thread sleep for .7 seconds to let GStreamer get caught up 
            Thread.usleep(700000);

            // Turn the volume back up
            for(double j = 0.1; j <= 1; j += 0.1) {
                set_volume(j);
                Thread.usleep(10000);
            }
        }
        
        /*
         * Set the player to a designated state
         */
        public void set_state (Gst.State s) {
            if(s == Gst.State.PLAYING) {
                is_currently_playing = true;
            } else {
                is_currently_playing = false;
            }
            playbin.set_state (s);
        }

		/*
		 * Sets the current volume
		 */
	    public void set_volume (double val) {
	        playbin.set_property ("volume", val);
	    }
    }
}
