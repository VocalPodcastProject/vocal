/***

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
  
  Note: Parts of this MPRIS implementation are inspired by the Noise
  MPRIS plugin:

  		Original Authors: Andreas Obergrusberger
                   			Jörn Magens
 
 		Edited by: Scott Ringwelski

  BEGIN LICENSE
***/

using Gee;
using GLib;
 
namespace Vocal { 

    public class MPRIS : GLib.Object {
	    public MprisPlayer 	player = null;
	    public MprisRoot 	root = null;
	
	    private MainWindow  window;

	    private unowned 	DBusConnection conn;
	    private uint 		owner_id;

		/*
		 * Default constructor that simply sets the window
		 */
	    public MPRIS(MainWindow w) {
	        this.window = w;
	    }

		/*
		 * Initializes MPRIS support
		 */
	    public void initialize() {
	        
		    owner_id = Bus.own_name(BusType.SESSION,
		                            "org.mpris.MediaPlayer2.Vocal",
		                            GLib.BusNameOwnerFlags.NONE,
                            		on_bus_acquired,
                            		on_name_acquired,
                            		on_name_lost);

		    if(owner_id == 0) {
			    warning("Could not initialize MPRIS session.\n");
		    }  
	    }

		/*
		 * Handler for when the DBus connection gets acquired
		 */
	    private void on_bus_acquired(DBusConnection connection, string name) {
		    this.conn = connection;
		    debug("bus acquired\n");
		    try {
			    root = new MprisRoot();
			    connection.register_object("/org/mpris/MediaPlayer2", root);

			    root.quit_requested.connect(() => {
			    	window.destroy();
		    	});
			    root.raise_requiested.connect(() => {
			    	window.present();
		    	});

			    
			    player = new MprisPlayer(connection);

			    // Set up all the signals
			    window.track_changed.connect(player.set_media_metadata);
			    window.playback_status_changed.connect(player.set_playback_status);

			    player.play.connect(() => {
			    	window.play();
		    	});

		    	player.next.connect(() => {
		    		window.seek_forward();
		    	});

		    	player.previous.connect(() => {
		    		window.seek_backward();
		    	});

			    connection.register_object("/org/mpris/MediaPlayer2", player);
			    

		    } 
		    catch(IOError e) {
			    warning("could not create MPRIS player: %s\n", e.message);
		    }
	    }

		/*
		 * Handler for when the name gets acquired
		 */
	    private void on_name_acquired(DBusConnection connection, string name) {
		    info("name acquired\n");
	    }	

		/*
		 * Handler for when the name gets lost
		 */
	    private void on_name_lost(DBusConnection connection, string name) {
		    info("name_lost\n");
	    }
    }
    
    [DBus(name = "org.mpris.MediaPlayer2.Player")]
    public class MprisPlayer : GLib.Object {
	    private unowned DBusConnection conn;
	    
	    public signal void play();
	    public signal void next();
	    public signal void previous();

	    private uint send_property_source = 0;
	    private uint update_metadata_source = 0;
	    private HashTable<string,Variant> changed_properties = null;
	    private HashTable<string,Variant> _metadata;
	    private string playback_status = "Stopped";


	    private const string INTERFACE_NAME = "org.mpris.MediaPlayer2.Player";
	    const string TRACK_ID = "/net/launchpad/vocal/Track/%d";

	    public MprisPlayer(DBusConnection conn) {
		    this.conn = conn;

		    // Set the metadata on initialization
		    this.set_media_metadata(" ", " ", """file:///usr/share/vocal/vocal-missing.png""", 60);
	    }

	    // MPRIS requires a mpris:trackid metadata item.
	    private GLib.ObjectPath get_track_id(string s) { 
		    string id = TRACK_ID.printf(s);
		    return new GLib.ObjectPath(id);
	    }

	    private void trigger_metadata_update() {
	        if(update_metadata_source != 0)
	            Source.remove(update_metadata_source);

	        update_metadata_source = Timeout.add(300, () => {

	            Variant variant = this.PlaybackStatus;
	            
	            queue_property_for_notification("PlaybackStatus", variant);
	            queue_property_for_notification("Metadata", _metadata);
	            update_metadata_source = 0;
	            return false;
	        });
	    }

	    public void set_media_metadata (string episode_title, string podcast, string art_uri, uint64 duration) {
	        _metadata = new HashTable<string, Variant> (null, null);

	        _metadata.insert("mpris:trackid", get_track_id (episode_title));
	        _metadata.insert("mpris:length", duration);

	        _metadata.insert("mpris:artUrl", art_uri);
	        _metadata.insert("xesam:title", episode_title);
	        _metadata.insert("xesam:album", podcast);
	        _metadata.insert("xesam:artist", podcast);
	        _metadata.insert("xesam:albumArtist", podcast);

	        trigger_metadata_update();
	    }


	    private bool send_property_change() {
        
	        if(changed_properties == null)
	            return false;
	        
	        var builder             = new VariantBuilder(VariantType.ARRAY);
	        var invalidated_builder = new VariantBuilder(new VariantType("as"));
	        
	        foreach(string name in changed_properties.get_keys()) {
	            Variant variant = changed_properties.lookup(name);
	            builder.add("{sv}", name, variant);
	        }
	        
	        changed_properties = null;
	        
	        try {
	            conn.emit_signal (null,
	                              "/org/mpris/MediaPlayer2", 
	                              "org.freedesktop.DBus.Properties", 
	                              "PropertiesChanged", 
	                              new Variant("(sa{sv}as)", 
	                                         INTERFACE_NAME, 
	                                         builder, 
	                                         invalidated_builder)
	                             );
	        }
	        catch(Error e) {
	            print("Could not send MPRIS property change: %s\n", e.message);
	        }
	        send_property_source = 0;
	        return false;
	    }
	    
	    private void queue_property_for_notification(string property, Variant val) {
	        // putting the properties into a hashtable works as akind of event compression
	        
	        if(changed_properties == null)
	            changed_properties = new HashTable<string,Variant>(str_hash, str_equal);
	        
	        changed_properties.insert(property, val);
	        
	        if(send_property_source == 0) {
	            send_property_source = Idle.add(send_property_change);
	        }
	    }

	    public void set_playback_status(string status)
	    {
	    	this.playback_status = status;

	    	trigger_metadata_update();
	    }


	    public double Volume {
            get {
            	return 1.0;
            } set {

            }
	    }

	    public int64 Position {
		    get {
		    	return 0;
		    }
	    }

	    public double Rate {
		    get {	
		    	return 1.0;
	    	}
	    }

	    public bool Shuffle {
	    	get {
	    		return false;
	    	}
	    }


	    public bool CanGoNext {
		    get {
			    return true;
		    }
	    }

	    public bool CanGoPrevious {
		    get {
			    return true;
		    }
	    }

	    public bool CanPlay {
		    get {
			    return true;
		    }
	    }

	    public bool CanPause {
		    get {
			    return true;
		    }
	    }

	    public bool CanSeek {
		    get {
			    return true;
		    }
	    }

	    public bool CanControl {
		    get {
			    return true;
		    }
	    }

	    public signal void Seeked(int64 Position);

	    public void Next() {
            next();
	    }

	    public void Previous() {
            previous();
	    }

	    public void Pause() {
            play();
	    }

	    public void PlayPause() {
            play();
	    }

	    public void Stop() {
            play();
	    }

	    public void Play() {
            play();
	    }

	    public void Seek(int64 Offset) {
	        
        }
    
	    public void SetPosition(string dobj, int64 Position) {
	        Seeked(Position);
	    }
	    
	    public void OpenUri(string Uri) {
	        
	    }

	    public string LoopStatus {
	    	get {
    			return "None";
			}
    	}

	    public string PlaybackStatus {
	    	get {
	    		return playback_status;
    		}
	    }

	    public HashTable<string,Variant>? Metadata { //a{sv}
	        owned get {
	            return _metadata;
	        }
    	}
    }

    [DBus(name = "org.mpris.MediaPlayer2")]
	public class MprisRoot : GLib.Object {

		public signal void quit_requested();
		public signal void raise_requiested();

	    public bool CanQuit { 
	        get {
	            return true;
	        } 
	    }

	    public bool CanRaise { 
	        get {
	            return true;
	        } 
	    }
	    
	    public string DesktopEntry { 
	        owned get {
	            return "vocal";
	        } 
	    }
	    
	    public bool HasTrackList {
	        get {
	            return false;
	        }
	    }
	    
	    
	    public string Identity {
	        owned get {
	            return "Vocal";
	        }
	    }
	    
	    public string[] SupportedMimeTypes {
			    owned get {
				    string[] sa = {
				        "audio/3gpp",
						"audio/aac",
						"audio/AMR",
						"audio/AMR-WB",
						"audio/ac3",
						"audio/basic",
						"audio/flac",
						"audio/mp2",
						"audio/mpeg",
						"audio/mp4",
						"audio/ogg",
						"audio/vnd.rn-realaudio",
						"audio/vorbis",
						"audio/x-aac",
						"audio/x-aiff",
						"audio/x-ape",
						"audio/x-flac",
						"audio/x-gsm",
						"audio/x-it",
						"audio/x-m4a",
						"audio/x-matroska",
						"audio/x-mod",
						"audio/x-ms-asf",
						"audio/x-ms-wma",
						"audio/x-mp3",
						"audio/x-mpeg",
						"audio/x-musepack",
						"audio/x-pn-aiff",
						"audio/x-pn-au",
						"audio/x-pn-realaudio",
						"audio/x-pn-realaudio-plugin",
						"audio/x-pn-wav",
						"audio/x-pn-windows-acm",
						"audio/x-realaudio",
						"audio/x-real-audio",
						"audio/x-sbc",
						"audio/x-speex",
						"audio/x-tta",
						"audio/x-vorbis",
						"audio/x-vorbis+ogg",
						"audio/x-wav",
						"audio/x-wavpack",
						"audio/x-xm",
						"application/ogg",
						"application/x-extension-m4a",
						"application/x-extension-mp4",
						"application/x-flac",
						"application/x-ogg"
				    };
				    return sa;
			    }
		    }
		    
	    public string[] SupportedUriSchemes {
	        owned get {
	            string[] sa = {"http", "file", "https", "ftp"};
	            return sa;
	        }
	    }

	    public void Quit () {
	        quit_requested();
	    }
	    
	    public void Raise () {
	        raise_requiested();
	    }
	}


    
}
