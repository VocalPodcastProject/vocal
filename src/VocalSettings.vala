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

namespace Vocal {
    public class VocalSettings {

        private static VocalSettings _default_instance = null;
        public signal void changed(string key);

        private GLib.Settings settings = new GLib.Settings("com.github.VocalPodcastProject.vocal");

        private VocalSettings () {
            settings.changed.connect((key) => {
                changed (key);
            });
        }

        public static VocalSettings get_default_instance () {
            if (_default_instance == null)
                _default_instance = new VocalSettings ();

            return _default_instance;
        }

        public bool auto_download {
            get { return settings.get_boolean("auto-download");}
            set { settings.set_boolean("auto-download", value);}
        }

        public bool autoclean_library {
            get { return settings.get_boolean("autoclean-library");}
            set { settings.set_boolean("autoclean-library", value);}
        }

        public bool continue_running_after_close {
            get { return settings.get_boolean("continue-running-after-close");}
            set { settings.set_boolean("continue-running-after-close", value);}
        }

        public bool gpodder_remove_deleted_podcasts {
            get { return settings.get_boolean("gpodder-remove-deleted-podcasts");}
            set { settings.set_boolean("gpodder-remove-deleted-podcasts", value);}
        }

        public bool gpodder_sync_episode_status {
            get { return settings.get_boolean("gpodder-sync-episode-status");}
            set { settings.set_boolean("gpodder-sync-episode-status", value);}
        }

        public bool keep_playing_in_background {
            get { return settings.get_boolean("keep-playing-in-background");}
            set { settings.set_boolean("keep-playing-in-background", value);}
        }

        public bool newest_episodes_first {
            get { return settings.get_boolean("newest-episodes-first");}
            set { settings.set_boolean("newest-episodes-first", value);}
        }

        public bool show_name_label {
            get { return settings.get_boolean("show-name-label");}
            set { settings.set_boolean("show-name-label", value);}
         }



        public int update_interval {
            get { return settings.get_int("update-interval");}
            set { settings.set_int("update-interval", value);}
        }

        public int window_height {
            get { return settings.get_int("window-height");}
            set { settings.set_int("window-height", value);}
        }

        public int window_width {
            get { return settings.get_int("window-width");}
            set { settings.set_int("window-width", value);}
        }


        public int fast_forward_seconds {
            get { return settings.get_int("fast-forward-seconds");}
            set { settings.set_int("fast-forward-seconds", value);}
        }

        public int rewind_seconds {
            get { return settings.get_int("rewind-seconds");}
            set { settings.set_int("rewind-seconds", value);}
        }



        public string gpodder_device_name {
            owned get {
               return  settings.get_string("gpodder-device-name");
            }
            set { settings.set_string("gpodder-device-name", value);}
        }

        public string gpodder_last_successful_sync_timestamp {
            owned get {
               return  settings.get_string("gpodder-last-successful-sync-timestamp");
            }
            set { settings.set_string("gpodder-last-successful-sync-timestamp", value);}
        }

        public string gpodder_username {
            owned get {
               return  settings.get_string("gpodder-username");
            }
            set { settings.set_string("gpodder-username", value);}
        }

        public string itunes_store_country {
            owned get {
               return  settings.get_string("itunes-store-country");
            }
            set { settings.set_string("itunes-store-country", value);}
        }

        public string last_played_media {
            owned get {
               return  settings.get_string("last-played-media");
            }
            set { settings.set_string("last-played-media", value);}
        }

        public string theme_preference {
            owned get {
               return  settings.get_string("theme-preference");
            }
            set { settings.set_string("theme-preference", value);}
        }
    }
}

