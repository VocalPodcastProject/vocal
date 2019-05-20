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

using Gee;

namespace Vocal {
    public class Podcast {

        public  ArrayList<Episode> episodes = null;  // the episodes belonging to this podcast

        public string       name = "";               // podcast name
        public string       feed_uri = "";           // the uri for the podcast
        public string       remote_art_uri = "";     // the web link to the album art if local is unavailable
        public string       local_art_uri = "";      // where the locally cached album art is located
        public string       description = "";        // the episode's description
        public MediaType    content_type;            // is the podcast an audio or video feed?
        public License license = License.UNKNOWN; // the type of license

        /*
         * Gets and sets the coverart, whether it's from a remote source
         * or locally cached.
         */
        public string coverart_uri {

            // If the album art is saved locally, return that path. Otherwise, return main album art URI.
            owned get {
                string[] uris = { local_art_uri, remote_art_uri };
                foreach (string uri in uris) {
                    if (uri != null && uri != "") {
                        GLib.File art = GLib.File.new_for_uri (uri);
                        if (art.query_exists ()) {
                            return uri;
                        }
                    }
                }
                // In rare instances where album art is not available at all, provide a "missing art" image to use
                // in library view
                return "resource:///com/github/needleandthread/vocal/missing.png";
            }

            // If the URI begins with "file://" set local uri, otherwise set the remote uri
            set {
                string[] split = value.split(":");
                string proto = split[0].ascii_down();
                if(proto == "http" || proto == "https") {
                    remote_art_uri = value.replace("%27", "'");
                } else {
                    local_art_uri = "file://" + value.replace("%27", "'");
                }
            }
        }


        /*
         * Default constructor for an empty podcast
         */
        public Podcast () {
            episodes = new ArrayList<Episode>();
            content_type = MediaType.UNKNOWN;
        }

        public Podcast.with_name(string name) {
            this();
            this.name = name;
        }

        /*
         * Add a new episode to the library
         */
        public void add_episode(Episode new_episode) {
            episodes.insert(0, new_episode);
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
