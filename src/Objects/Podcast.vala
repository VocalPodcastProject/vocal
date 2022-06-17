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

using Gee;

namespace Vocal {
    public class Podcast {

        public ArrayList<Episode> episodes = null;  // the episodes belonging to this podcast

        public string name = "";                    // podcast name
        public string feed_uri = "";                // the uri for the podcast
        public string remote_art_uri = "";          // the web link to the album art if local is unavailable
        public string description = "";             // the episode's description
        public MediaType content_type;              // is the podcast an audio or video feed?
        public License license = License.UNKNOWN;   // the type of license


        /*
         * Default constructor for an empty podcast
         */
        public Podcast () {
            episodes = new ArrayList<Episode> ();
            content_type = MediaType.UNKNOWN;
        }

        public Podcast.with_name (string name) {
            this ();
            this.name = name;
        }

        /*
         * Add a new episode to the library
         */
        public void add_episode (Episode new_episode) {
            new_episode.podcast_uri = this.feed_uri;
            episodes.insert (0, new_episode);
        }

    }


    /*
     * The possible types of media that a podcast might contain, generally either audio or video.
     */
    public enum MediaType {
        AUDIO, VIDEO, UNKNOWN;
    }

    /*
     * The legal license that a podcast is listed as (if known)
     */
    public enum License {
        UNKNOWN, RESERVED, CC, PUBLIC;
    }

}
