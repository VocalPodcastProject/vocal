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
    
        public  ArrayList<Episode> episodes = null;		  // the episodes belonging to this podcast
        
        public string 		name;                         // podcast name
        public string 		feed_uri;                     // the uri for the podcast
        public string 		remote_art_uri;               // the web link to the album art if local is unavailable
        public string 		local_art_uri;                // where the locally cached album art is located
        public string 		description;				  // the episode's description
        public MediaType 	content_type;                 // is the podcast an audio or video feed?

		/*
		 * Gets and sets the coverart, whether it's from a remote source
		 * or locally cached.
		 */
	    public string 		coverart_uri {				  

		    // If the album art is saved locally, return that path. Otherwise, return main album art URI
		    get {

		        if(local_art_uri != null) {
                GLib.File local_art = GLib.File.new_for_uri(local_art_uri);
                if(local_art.query_exists()) { 
                    return local_art_uri;
                } else {
                    GLib.File remote_art = GLib.File.new_for_uri(remote_art_uri);
                    if(remote_art.query_exists()) {
                        return remote_art_uri;
                    } else {
                        return """file:///usr/share/vocal/vocal-missing.png""";
                    }
                }
            }
	          else if(remote_art_uri != null) {
                GLib.File remote_art = GLib.File.new_for_path(remote_art_uri);
                if(remote_art.query_exists()) {
                    return remote_art_uri;
                } else {
                    return """file:///usr/share/vocal/vocal-missing.png""";
                }
            }
	                
	                
            // In rare instances where album art is not available at all, provide a "missing art" image to use
            // in library view
            else {
                return """file:///usr/share/vocal/vocal-missing.png""";
            }
                
		    }
		    
		    // If the URI begins with "file://" set local uri, otherwise set the remote uri
		    set {
		        string[] split = value.split(":");
		        if(split[0] == "http" || split[0] == "HTTP") {
		            remote_art_uri = value.replace("%27", "'");
            } else {
                local_art_uri = """file://""" + value.replace("%27", "'");
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

}
