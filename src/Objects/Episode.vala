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

namespace Vocal {

    public class Episode : GLib.Object {

        public string guid = null;
        public string link = "";
        public string podcast_uri = null;
        public string title = "";                       // the title of the episode
        public string description = "";                 // the description/shownotes
        public string uri = "";                         // the remote location for the media file
        public string local_uri = "";                   // the local location for the media file, if any
        public uint64 last_played_position;             // the latest position that has been played
        public string date_released;                    // when the episode was released, in string form
        public string duration;                         // how long the episode is

        public EpisodeStatus status;                    // whether the episode is played or unplayed
        public DownloadStatus current_download_status;  // whether the episode is downloaded or not downloaded

        public Podcast parent;                          // the parent that the episode belongs to
        public DateTime datetime_released;              // the datetime corresponding the when the episode was released

        /*
         * Gets the playback uri based on whether the file is local or remote
         * (and if it is local, by making sure it actually exists on disk)
         *
         * Sets the playback uri (and corresponding fields) based on whether it's
         * local or remote
         */
        public string playback_uri {

            get {

                GLib.File local;

                if (local_uri != null) {

                    if (local_uri.contains ("file://"))
                        local = GLib.File.new_for_uri (local_uri);
                    else
                        local = GLib.File.new_for_uri ("file://" + local_uri);
                    if (local.query_exists ()) {

                        if (local_uri.contains ("file://"))
                            return local_uri;
                        else {
                            local_uri = "file://" + local_uri;
                            return local_uri;
                        }

                    } else {

                        return uri;
                    }
                }

                else {
                    return uri;
                }

            }

            // If the URI begins with "file://" set local uri, otherwise set the remote uri
            set {
                string[] split = value.split (":");
                if (split[0] == "http" || split[0] == "HTTP") {
                    uri = value;
                } else {
                    if (!value.contains ("file://")) {
                        local_uri = """file://""" + value;
                    }
                    else {
                        local_uri = value;
                    }
                }
            }
        }

        /*
         * Default constructor for an empty episode. Fields are public members and can
         * be accessed and set directly when necessary by other classes.
         */
        public Episode () {
            parent = null;
            local_uri = null;
            status = EpisodeStatus.UNPLAYED;
            current_download_status = DownloadStatus.NOT_DOWNLOADED;
            last_played_position = 0;

        }

        /*
         * Sets the local datetime based on the standardized "pubdate" as listed
         * in the feed.
         */
        public void set_datetime_from_pubdate () {

            if (date_released != null) {
                GLib.Time tm = GLib.Time ();
                // Set a default time of now in case a time cannot be parsed
                // from the pubdate string.
                tm.mktime ();
                // Supported time formats.
                // The specification (https://cyber.harvard.edu/rss/rss.html)
                // states that datetimes should be in RFC 822 format,
                // but date strings with different formats can cause a crash.
                string[] time_formats = {
                    "%a, %d %b %Y %H:%M:%S %Z",  // Sunday, 01 Jan 1970 00:00:00 GMT
                    "%a, %b %d %Y %H:%M:%S %Z"  // Sunday, Jan 01 1970 00:00:00 GMT
                };
                foreach (string format in time_formats) {
                    var last_parsed_char = tm.strptime (date_released, format);
                    if (last_parsed_char != null) {
                        break;
                    }
                }
                datetime_released = new DateTime.local (
                    1900 + tm.year,
                    1 + tm.month,
                    tm.day,
                    tm.hour,
                    tm.minute,
                    tm.second
                );
            }
        }

    }

    /*
     * Possible episode playback statuses, either played or unplayed. In Vocal 2.0 it would be
     * beneficial to have an additional value to determine if the episode is finished
     * or simply started.
     */
    public enum EpisodeStatus {
        PLAYED, UNPLAYED;
    }

    /*
     * Possible episode download statuses, either downloaded or not downloaded.
     */
    public enum DownloadStatus {
        DOWNLOADED, NOT_DOWNLOADED;
    }
}
