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

using GLib;

namespace Vocal {

    public class Episode {
    
        public string			title;        			// the title of the episode
        public string			description;			// the description/shownotes
        public string			uri;					// the remote location for the media file
        public string			local_uri;				// the local location for the media file, if any
        public int64 			last_played_position;	// the latest position that has been played
        public string 			date_released;			// when the episode was released, in string form
        public EpisodeStatus	status;					// whether the episode is played or unplayed
        public DownloadStatus	current_download_status;// whether the episode is downloaded or not downloaded
        
        public Podcast 			parent;					// the parent that the episode belongs to
        public DateTime 		datetime_released;		// the datetime corresponding the when the episode was released

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

                if(local_uri != null) {
                    if(local_uri.contains("file://"))
                        local = GLib.File.new_for_uri(local_uri);
                    else 
                        local = GLib.File.new_for_uri("file://" + local_uri);
                    if(local.query_exists()) { 
                        if(local_uri.contains("file://"))
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
                string[] split = value.split(":");
                if(split[0] == "http" || split[0] == "HTTP") {
                    uri = value;
                } else {
                    if(!value.contains("file://")) {
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
        public Episode() {
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
        public void set_datetime_from_pubdate() {
        
            // Split all the fields (command, colon, and space delimited)
            string[] fields = date_released.split_set(",: ");

            // The offset refers to the index position
            // The datetime field is typically standardized, but one
            // very rare cases the first field may not contain the day of the week
            int offset = 0;

            // See if the first field is a number. If so, the day of the week isn't first
            bool no_day_of_week = int64.try_parse(fields[0]);

            if(no_day_of_week) {
                offset = -2;
            }

            
        
            // Since the pubdate is a standard, we can hard-code the values where each item is located
            
            int day = int.parse(fields[2 + offset]);
            int year = int.parse(fields[4 + offset]);
            int hour = int.parse(fields[5 + offset]);
            int minute = int.parse(fields[6 + offset]);
            int seconds = int.parse(fields[7 + offset]);
                
            
            // Determine the month number from the string as read from the pubdate
            int month = 1;
            
            switch(fields[3 + offset]) {
                case "Jan":
                    month = 1;
                    break;
                case "Feb":
                    month = 2;
                    break;
                case "Mar":
                    month = 3;
                    break;
                case "Apr":
                    month = 4;
                    break;
                case "May":
                    month = 5;
                    break;
                case "Jun":
                    month = 6;
                    break;
                case "Jul":
                    month = 7;
                    break;
                case "Aug":
                    month = 8;
                    break;
                case "Sep":
                    month = 9;
                    break;
                case "Oct":
                    month = 10;
                    break;
                case "Nov":
                    month = 11;
                    break;
                case "Dec":
                    month = 12;
                    break;
                
            }
            
            // Create the datetime object (assume pubdate is UTC)
            var datetime_utc = new DateTime.utc(year, month, day, hour, minute, (double)seconds);
            
            // Convert from UTC to system local time
            datetime_released = datetime_utc.to_local();
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
