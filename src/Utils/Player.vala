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

using GLib;
using Gst;
using Gst.PbUtils;

namespace Vocal {
    public class Player {

        public signal void position_updated (uint64 pos, uint64 duration);
        public signal void track_changed (string episode_title, string podcast_name, string artwork_uri, uint64 duration, string? description);
        public signal void playback_status_changed (string status);
        public signal void additional_plugins_required (Gst.Message message);
        public signal void end_of_stream();
        public signal void update_episode_position(Episode episode, uint64 position);

        private static Player? player = null;
        public static Player? get_default () {
            if (player == null) {
                player = new Player ();
            }
            return player;
        }

        public bool playing = false;
        private Gst.Player p;

        public Episode current_episode;

        private Player () {

            p = new Gst.Player(null, null);
            p.position_updated.connect((pos) => {
                position_updated(pos, p.duration);
            });

            p.state_changed.connect((state) => {
                if(state == Gst.PlayerState.PLAYING) {
                    playback_status_changed("Playing");
                } else if (state == Gst.PlayerState.PAUSED) {
                    playback_status_changed("Paused");
                } else {
                    playback_status_changed("Stopped");
                }
            });

            p.end_of_stream.connect(() => { end_of_stream(); });
        }



        public void set_uri (string uri) {
            p.set_uri(uri);
        }


        /*
         * Sets the current state to pause
         */
        public void pause () {
            p.pause();
            playing = false;
        }

        /*
         * Sets the current state to playing
         */
        public void play () {
            p.play();
            playing = true;
        }

        /*
         * Pauses if playing, and plays if paused
         */
        public void play_pause () {
            if (playing) {
                pause ();
            } else {
                play ();
            }
        }

        /*
         * Seeks backward in the currently playing media n number of seconds
         */
        public void skip_back (uint64 seconds) {
            p.seek(p.get_position() - (seconds * 1000000000));
        }

        /*
         * Seeks forward in the currently playing media n number of seconds
         */
        public void skip_forward (uint64 seconds) {
            p.seek((p.get_position() + (seconds * 1000000000)));
        }

        /*
         * Sets the episode that is currently being played
         */
        public void set_episode (Episode episode) {

            // Tell the controller we need to save the episode position
            if(current_episode != null)
                update_episode_position(current_episode, p.position);

            p.pause();
            p.stop();
            this.current_episode = episode;

            set_uri(episode.playback_uri);
            track_changed(episode.title, episode.parent.name, episode.parent.remote_art_uri, p.duration, episode.description);


            // Start back at last played position
            if(episode.last_played_position > 0) {
                set_position(episode.last_played_position);
            }
        }

        /*
         * Change the playback rate
         */

        public void set_rate (double rate) {
            p.set_rate(rate);
        }


        /*
         * Sets the currently playing media position, in seconds
         */
		public void set_position (uint64 position) {
		    p.seek(position);
		}

		public uint64 get_position () {
		    return p.position;
		}

		public void set_percentage (double pos) {
            p.seek((Gst.ClockTime)(p.duration * pos));
		}

		public uint64 get_duration() {
		    return p.duration;
		}


        /*
         * Sets the current volume
         */
        public void set_volume (double val) {
            p.volume = val;
        }

        /*
         * Gets the current volume
         */
        public double get_volume () {
            return p.volume;
        }

        /*
         * Starts playback when we have part of the episode downloaded
         */
        public void streaming_delegate (int64 current_num_bytes, int64 total_num_bytes) {

            if (current_num_bytes > 0 && ((double)current_num_bytes / total_num_bytes > 0.1) && p.uri != "file://" + GLib.Environment.get_user_cache_dir () + "/stream") {
                set_uri("file://" + GLib.Environment.get_user_cache_dir () + "/stream");
                track_changed(current_episode.title, current_episode.parent.name, current_episode.parent.remote_art_uri, p.duration, current_episode.description);
                play();
            }
        }
    }
}
