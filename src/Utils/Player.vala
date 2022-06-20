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
        public signal void track_changed (string episode_title, string podcast_name, string artwork_uri, uint64 duration);
        public signal void playback_status_changed (string status);
        public signal void additional_plugins_required (Gst.Message message);

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

            this.current_episode = episode;
            set_uri(episode.playback_uri);
            track_changed(episode.title, episode.parent.name, episode.parent.remote_art_uri, p.duration);
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
		public void set_position (double position) {
		    var new_pos = (uint64) (p.duration * position);
            p.seek(new_pos);
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
    }
}
