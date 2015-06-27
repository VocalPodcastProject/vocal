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
using Gst;
using GLib;
using Sqlite;


namespace Vocal {


    errordomain VocalLibraryError {
        ADD_ERROR, IMPORT_ERROR; 
    }
    
    
    class Library {

		// Fired when a download completes
        public signal void	download_finished(Episode episode);
        
        // Fired when there is an update during import
        public signal void 	import_status_changed(int current, int total, string name);
        
        // Fired when there is a new, new episode count
        private signal void new_episode_count_changed();
        
        public ArrayList<Podcast> podcasts;		// Holds all the podcasts in the library
        
        private Sqlite.Database db;				// The database
        
        private string db_location = null;
        private string vocal_config_dir = null;
        private string db_directory = null;
        private string local_library_path;
        
#if HAVE_LIBUNITY
        private Unity.LauncherEntry launcher;
#endif
        
        private FeedParser parser;				// Parser for parsing feeds
		private VocalSettings settings;			// Vocal's settings
		
        Episode downloaded_episode = null;
        
        private int _new_episode_count;		
        public int new_episode_count { 
            get { return _new_episode_count; }
            
            set {
                _new_episode_count = value;
                new_episode_count_changed();             
            }
        }
        
        /*
         * Constructor for the library
         */
        public Library() {
        
            vocal_config_dir = GLib.Environment.get_user_config_dir() + """/vocal""";
            this.db_directory = vocal_config_dir + """/database""";
            this.db_location = this.db_directory + """/vocal.db""";

            this.podcasts = new ArrayList<Podcast>();

            settings = new VocalSettings();
            
            // Set the local library path (and replace ~ with the absolute home directory if need be) 
            local_library_path = settings.library_location.replace("~", GLib.Environment.get_home_dir());
            
            parser = new FeedParser();
            
#if HAVE_LIBUNITY
            launcher = Unity.LauncherEntry.get_for_desktop_id("vocal.desktop");
            launcher.count = new_episode_count;
#endif

            new_episode_count_changed.connect(set_new_badge);
            new_episode_count = 0;
        }
        
        
        
        /*
         * Adds podcasts to the library from the provided OPML file path
         */
        public async bool add_from_OPML(string path) {
        
            bool successful = true;

            SourceFunc callback = add_from_OPML.callback;
            
            ThreadFunc<void*> run = () => {
                
                try {

                    string[] feeds = parser.parse_feeds_from_OPML(path);
                    int i = 0;
                    foreach (string feed in feeds) {
                        i++;
                        import_status_changed(i, feeds.length, feed);
                        bool temp_status = add_podcast_from_file(feed);
                        if(temp_status == false)
                            successful = false;
                    }
                    
                } catch (Error e) {
                    info("Error parsing OPML file.");
                    info(e.message);
                    successful = false;
                    
                }
                
                
                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);
            
            yield;

            return successful;
        }
        
        
        
        /*
         * Adds a new podcast to the library
         */
        public bool add_podcast(Podcast podcast) throws VocalLibraryError {
            
            if(podcast == null){
                throw new VocalLibraryError.ADD_ERROR(_("Unable to add podcast"));
            }
            
            // Set all but the most recent episode as played on initial add to library
            if(podcast.episodes.size > 0) {
                for(int i = 0; i < podcast.episodes.size-1; i++) {
                    podcast.episodes[i].status = EpisodeStatus.PLAYED;
                }
            }
            
            string podcast_path = local_library_path + "/%s".printf(podcast.name.replace("%27", "'").replace("%", "_"));
            
            // Create a directory for downloads and artwork caching in the local library
            GLib.DirUtils.create_with_parents(podcast_path, 0775);

            
            //  Locally cache the album art if necessary
            try {
            
                // Don't use the default coverart_path getter, we want to make sure we are using the remote URI
                GLib.File remote_art = GLib.File.new_for_uri(podcast.remote_art_uri); 
                
                // Set the path of the new file and create another object for the local file

                string art_path = podcast_path + """/""" + remote_art.get_basename().replace("%", "_");
                
                GLib.File local_art = GLib.File.new_for_path(art_path);
                
                // If the local album art doesn't exist
                if(!local_art.query_exists()) {

                    // Cache the art
                    remote_art.copy(local_art, FileCopyFlags.NONE);
                    
                    // Mark the local path on the podcast
                    podcast.local_art_uri = """file://""" + art_path;
                }
                
            } catch(Error e) {
                stderr.puts("Unable to save a local copy of the album art.\n");
            }
            
                       
            // Open the database
            int ec = Sqlite.Database.open (db_location, out db);
	        if (ec != Sqlite.OK) {
		        stderr.printf ("Can't open database: %d: %s\n", db.errcode (), db.errmsg ());
		        return false;
	        }
	        
	        string content_type_text;
	        string played_text;

	        if(podcast.content_type == MediaType.AUDIO) {
	            content_type_text = "audio";
	        }
	        else if(podcast.content_type == MediaType.VIDEO) {
	            content_type_text = "video";
	        }
	        else {
	            content_type_text = "unknown";
	        }
	        
 
            // Add the podcast 
            
            string name, feed_uri, album_art_url, album_art_local_uri, description;
            
            name = podcast.name.replace("'", "%27");
            feed_uri = podcast.feed_uri.replace("'", "%27");
            album_art_url = podcast.remote_art_uri.replace("'", "%27");
            album_art_local_uri = podcast.local_art_uri.replace("'", "%27");
            description = podcast.description.replace("'", "%27");
            
            
            
            string query = """INSERT OR REPLACE INTO Podcast (name, feed_uri, album_art_url, album_art_local_uri, description, content_type)
                VALUES ('%s','%s','%s','%s', '%s', '%s');""".printf(name, feed_uri, album_art_url, album_art_local_uri,
                description, content_type_text);
                
                
            string errmsg;
            
            
            ec = db.exec (query, null, out errmsg);
	        if (ec != Sqlite.OK) {
		        stderr.printf ("Error: %s\n", errmsg);
		        return false;
	        }
	        
	        // Now that the podcast is in the database, add it to the local arraylist
	        podcasts.add(podcast);
	        

            foreach(Episode episode in podcast.episodes) {
                string title, parent_podcast_name, uri, episode_description;
                title = episode.title.replace("'", "%27");
                parent_podcast_name = podcast.name.replace("'", "%27");
                uri = episode.uri.replace("'", "%27");
                episode_description = episode.description.replace("'", "%27");
                
                if(episode.status == EpisodeStatus.PLAYED) {
	                played_text = "played";
	            }
	            else {
	                played_text = "unplayed";
	            }
	        
    	        string download_text;
	            if(episode.current_download_status == DownloadStatus.DOWNLOADED) {
	                download_text = "downloaded";
	            } else {
	                download_text = "not_downloaded";
	            }
                
                query = """INSERT OR REPLACE INTO Episode (title, parent_podcast_name, uri, local_uri, description, release_date, download_status, play_status) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s');"""
                    .printf(title, parent_podcast_name, uri, episode.local_uri, episode_description, episode.date_released, download_text, played_text);
                    
                
                ec = db.exec (query, null, out errmsg);
                if (ec != Sqlite.OK) {
                    stderr.printf ("Error: %s\n", errmsg);
                }
            }
            
	        
	        return true;
                
        }

		/*
		 * Adds a new podcast to the library from a given file path by parsing the file's contents
		 */
        public bool add_podcast_from_file(string path) {

            info("Adding podcast from file: %s".printf(path));
            parser = new FeedParser();
            
            Podcast new_podcast = parser.get_podcast_from_file(path);
            if(new_podcast == null) {
                return false;
            } else {
                add_podcast(new_podcast);
                return true;
            }

        }
        
        
        /*
         * Adds a new podcast from a file, asynchronously
         */
        public async bool async_add_podcast_from_file(string path) {
                    
            bool successful = true;

            SourceFunc callback = async_add_podcast_from_file.callback;   
            
            ThreadFunc<void*> run = () => {
            
                info("Adding podcast from file: %s".printf(path));
                parser = new FeedParser();
                
                try {
                    Podcast new_podcast = parser.get_podcast_from_file(path);
                    if(new_podcast == null) {
                        info("New podcast found to be null.");
                        successful = false;
                    } else {
                        add_podcast(new_podcast);
                    }
                } catch (Error e) {
                    successful = false;
                }
                
                    
                Idle.add((owned) callback);
                return null;

            };
            Thread.create<void*>(run, false);
            
            yield;

            return successful;
            
        } 

        /*
         * Checks library for downloaded episodes that are played and over a week old
         */
        public async void autoclean_library() {
        
        
            SourceFunc callback = autoclean_library.callback;
            
            ThreadFunc<void*> run = () => {
                // Create a new DateTime that is the current date and then subtract one week
                GLib.DateTime week_ago = new GLib.DateTime.now_utc();
                week_ago.add_weeks(-1);
            
                foreach(Podcast p in podcasts) {
                    foreach(Episode e in p.episodes) {
                    
                        // If e is downloaded, played, and more than a week old
                        if(e.current_download_status == DownloadStatus.DOWNLOADED &&
                            e.status == EpisodeStatus.PLAYED && e.datetime_released.compare(week_ago) == -1) {
                            
                            // Delete the episode. Skip checking for an existing file, the delete_episode method will do that automatically
                            info("Episode %s is more than a week old. Deleting.".printf(e.title));
                            delete_local_episode(e);
                        
                      
                        }
                    } 
                }
                
                Idle.add((owned) callback);
                return null;

            };
            Thread.create<void*>(run, false);
            
            yield;
        }
        
        /*
         * Checks to see if the local database file exists
         */
        public bool check_database_exists() {
            File file = File.new_for_path (db_location);
	        return file.query_exists ();
        }
        
        /*
         * Checks each feed in the library to see if new episodes are available
         */
        public async Gee.ArrayList<Episode> check_for_updates() throws VocalUpdateError{
        
            SourceFunc callback = check_for_updates.callback;
            Gee.ArrayList<Episode> new_episodes = new Gee.ArrayList<Episode>(); 

            parser = new FeedParser();        
            
            ThreadFunc<void*> run = () => {
                foreach(Podcast podcast in podcasts) {
                    try {               
                        int added = parser.update_feed(podcast);

                        while(added != 0) {
                            int index = podcast.episodes.size - added;
                            
                            // Add the new episode to the arraylist in case it needs to be downloaded later
                            
                            new_episodes.add(podcast.episodes[index]);
                            
                            write_episode_to_database(podcast.episodes[index]);
                            added--;
                        }
                        
                    } catch(Error e) { 
                        throw e;
                    }
                    
                }
                
                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);
            
            yield;

            return new_episodes;
        }
        
        /*
         * Deletes the local media file for an episode
         */
        public void delete_local_episode(Episode e) {

            // First check that the file exists
            GLib.File local = GLib.File.new_for_path(e.local_uri);
            if(local.query_exists()) {

                // Delete the file
                local.delete();
            }

            string query, errmsg;
            int ec;
            string title;
            
            // Clear the fields in the episode
            title = e.title.replace("'", "%27");
            e.current_download_status = DownloadStatus.NOT_DOWNLOADED;
            e.local_uri = null;

            // Write the episode to database
            query = """UPDATE Episode SET download_status = 'not_downloaded', local_uri = NULL WHERE title = '%s'""".printf(title);
                
                
            ec = db.exec (query, null, out errmsg);
            
            if (ec != Sqlite.OK) {
                error(errmsg);
            }

            recount_unplayed();
        }
        
        /*
         * Downloads a podcast to the local directory and creates a DownloadDetailBox that is useful
         * for displaying download progress information later
         */
        public DownloadDetailBox? download_episode(Episode episode) {
        
            // Check to see if the episode has already been downloaded
            if(episode.current_download_status == DownloadStatus.DOWNLOADED) {
                warning("Error. Episode %s is already downloaded.\n", episode.title);
                return null;
            }
            
            string library_location;
            
            
            
            if(settings.library_location != null) {
                library_location = settings.library_location;
            }
            else {
                library_location = GLib.Environment.get_user_data_dir() + """/vocal""";
            }
            
            
            // Create a file object for the remotely hosted file
            GLib.File remote_file = GLib.File.new_for_uri(episode.uri);

            DownloadDetailBox detail_box = null;
            
            // Set the path of the new file and create another object for the local file
            try {

                GLib.File test_cover = GLib.File.new_for_uri(episode.parent.coverart_uri);

                InputStream input_stream = test_cover.read();
                var pixbuf = new Gdk.Pixbuf.from_stream_at_scale(input_stream, 64, 64, true);
                
                string path = library_location + "/%s/%s".printf(episode.parent.name.replace("%27", "'").replace("%", "_"), remote_file.get_basename());
                info("Saving to path: " + path);
                GLib.File local_file = GLib.File.new_for_path(path);
                
                detail_box = new DownloadDetailBox(episode, pixbuf);
                detail_box.download_has_completed_successfully.connect(on_successful_download);
                FileProgressCallback callback = detail_box.download_delegate;
                GLib.Cancellable cancellable = new GLib.Cancellable();
                
                detail_box.cancel_requested.connect( () => {
                    
                    cancellable.cancel();
                    bool exists = local_file.query_exists();
                    if(exists) {
                        try {
                            local_file.delete();
                        } catch(Error e) {
                            stderr.puts("Unable to delete file.\n");
                        }
                    }
                    
                });
                
                remote_file.copy_async(local_file, FileCopyFlags.OVERWRITE, Priority.DEFAULT, cancellable, callback);
            
            
                // Set the episode's local uri to the new path
                episode.local_uri = path;
                
                   
            } catch (Error e) {
            }
            
            return detail_box; 
        }
        
        /*
         * Exports the current podcast subscriptions to a file at the provided path
         */
        public void export_to_OPML(string path) {
            File file = File.new_for_path (path);
	        try {
	            GLib.DateTime now = new GLib.DateTime.now(new TimeZone.local());
	            string header = """<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
<head>
    <title>Vocal Subscriptions Export</title>
    <dateCreated>%s</dateCreated>
    <dateModified>%s</dateModified>
</head>
<body>
    """.printf(now.to_string(), now.to_string());
		        FileIOStream stream = file.create_readwrite (FileCreateFlags.REPLACE_DESTINATION);
		        stream.output_stream.write (header.data);
		        
		        string output_line;
		        
		        foreach(Podcast p in podcasts) {
		        
		            output_line = 
    """<outline text="%s" type="rss" xmlUrl="%s"/>
    """.printf(p.name.replace("\"", "'").replace("&", "and"), p.feed_uri);
		            stream.output_stream.write(output_line.data);
		        }
		        
		        const string footer = """
</body>
</opml>
""";
		        
		        stream.output_stream.write(footer.data);
	        } catch (Error e) {
		        warning ("Error: %s\n", e.message);
	        }
        }
        
        /*
         * Marks all episodes in a given podcast as played
         */
        public void mark_all_episodes_as_played(Podcast highlighted_podcast) {
            foreach(Episode episode in highlighted_podcast.episodes) {
                mark_episode_as_played(episode);
            }
        }
        
        /*
         * Marks an episode as downloaded in the database
         */
        public void mark_episode_as_downloaded(Episode episode) {
            string query, errmsg;
            int ec;
            string title, uri;
            
            title = episode.title.replace("'", "%27");
            uri = episode.local_uri;

            query = """UPDATE Episode SET download_status = 'downloaded', local_uri = '%s' WHERE title = '%s'""".printf(uri,title);
                
                
            ec = db.exec (query, null, out errmsg);
            
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %s\n", errmsg);
            }
        }
        
        /*
         * Marks an episode as played in the database
         */
        public void mark_episode_as_played(Episode episode) {

            if(episode == null)
                error("Episode null!");
        
            episode.status = EpisodeStatus.PLAYED;
            string query, errmsg;
            int ec;
            string title;
            title = episode.title.replace("'", "%27");


            query = """UPDATE Episode SET play_status = 'played' WHERE title = '%s'""".printf(title);
                
            ec = db.exec (query, null, out errmsg);
            
            if (ec != Sqlite.OK) {
                error(errmsg);
            }
        }

        /*
         * Marks an episode as played in the database
         */
        public void mark_episode_as_unplayed(Episode episode) {
        
            episode.status = EpisodeStatus.UNPLAYED;

            string query, errmsg;
            int ec;
            string title;
            title = episode.title.replace("'", "%27");


            query = """UPDATE Episode SET play_status = 'unplayed' WHERE title = '%s'""".printf(title);
                
            ec = db.exec (query, null, out errmsg);
            
            if (ec != Sqlite.OK) {
                error(errmsg);
            }
        }
        
        /*
         * Notifies the user that a download has completed successfully
         */
        public void on_successful_download(string episode_title, string parent_podcast_name, Gdk.Pixbuf notification_pixbuf) {
        
            try {
                recount_unplayed();
                set_new_badge();
                
#if HAVE_LIBNOTIFY

                string message = "'%s' from '%s' has finished downloading.".printf(episode_title.replace("%27", "'"), parent_podcast_name.replace("%27","'"));
                var notification = new Notify.Notification("Episode Download Complete", message, null);
                notification.set_icon_from_pixbuf(notification_pixbuf);
                notification.show();

#endif
                
                // Find the episode in the library
                downloaded_episode = null;
                bool found = false;
                
                foreach(Podcast podcast in podcasts) {
                    if(!found) {
                        if(parent_podcast_name == podcast.name) {
                            foreach(Episode episode in podcast.episodes) {
                                if(episode_title == episode.title) {
                                    downloaded_episode = episode;
                                    found = true;
                                }
                            }

                        }
                    }
                }

                // If the episode was found (and it should have been), mark as downloaded and write to database
                if(downloaded_episode != null) {
                    downloaded_episode.current_download_status = DownloadStatus.DOWNLOADED;
                    mark_episode_as_downloaded(downloaded_episode);
                }
                
            } catch(Error error) {
            } finally {
                download_finished(downloaded_episode);
            }

        }
        
        /*
         * Opens the database and prepares for queries
         */
        private int prepare_database() {
            assert(db_location != null);
            
            // Open a database:
            int ec = Sqlite.Database.open (db_location, out db);
            if (ec != Sqlite.OK) {
	            stderr.printf ("Can't open database: %d: %s\n", db.errcode (), db.errmsg ());
	            return -1;
            }
            
            return 0;
        }
        
        
        /*
         * Iterates through each episode in the library to count the number of unplayed episodes
         */
        public void recount_unplayed() {
            new_episode_count = 0;
            foreach(Podcast p in podcasts) {
                foreach(Episode e in p.episodes) {
                    if(e.status == EpisodeStatus.UNPLAYED) {
                        new_episode_count++;
                    }
                }
            }

            set_new_badge();
        }
        
        /*
         * Refills the local library from the contents stored in the database
         */
        public void refill_library() {
        
            podcasts.clear();
            prepare_database();
            
            Sqlite.Statement stmt;

	        string prepared_query_str = "SELECT * FROM Podcast ORDER BY name";
	        int ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
	        if (ec != Sqlite.OK) {
		        warning("%d: %s\n".printf(db.errcode (), db.errmsg ()));
		        return;
	        }

	        // Use the prepared statement:
            
	        int cols = stmt.column_count ();
	        while (stmt.step () == Sqlite.ROW) {

	            Podcast current = new Podcast();
		        for (int i = 0; i < cols; i++) {
			        string col_name = stmt.column_name (i) ?? "<none>";
			        string val = stmt.column_text (i) ?? "<none>";
                    
                    if(col_name == "name") {
                        current.name = val;
                    }
                    else if(col_name == "feed_uri") {
                        current.feed_uri = val;
                    }
                    else if (col_name == "album_art_url") {
                        current.remote_art_uri = val;
                    }
                    else if (col_name == "album_art_local_uri") {
                        current.local_art_uri = val;
                    }
                    else if(col_name == "description") {
                        current.description = val;
                    }
                    else if (col_name == "content_type") {
                        if(val == "audio") {
                            current.content_type = MediaType.AUDIO;
                        }
                        else if(val == "video") {
                            current.content_type = MediaType.VIDEO;
                        }
                        else {
                            current.content_type = MediaType.UNKNOWN;
                        }
                    }
		        }
		        
		        //Add the new podcast
		        podcasts.add(current);
		        
	        }

	        stmt.reset();     
	        
	        
	        // Repeat the process with the episodes
	        
	        foreach(Podcast p in podcasts) {
	        
	            prepared_query_str = "SELECT * FROM Episode WHERE parent_podcast_name = '%s' ORDER BY rowid ASC".printf(p.name);
	            ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
	            if (ec != Sqlite.OK) {
		            stderr.printf ("Error: %d: %s\n", db.errcode (), db.errmsg ());
		            return;
	            }

                
	            cols = stmt.column_count ();
	            while (stmt.step () == Sqlite.ROW) {

	                Episode current_ep = new Episode();
	                current_ep.parent = p;
		            for (int i = 0; i < cols; i++) {
			            string col_name = stmt.column_name (i) ?? "<none>";
			            string val = stmt.column_text (i) ?? "<none>";
                        
                        if(col_name == "title") {
                            current_ep.title = val;
                        }
                        else if(col_name == "description") {
                            current_ep.description = val;
                        }
                        else if (col_name == "uri") {
                            current_ep.uri = val;
                        }
                        else if (col_name == "local_uri") {
                            if(val != "(null)")
                                current_ep.local_uri = val;
                        }
                        else if (col_name == "release_date") {
                            current_ep.date_released = val;
                            current_ep.set_datetime_from_pubdate();
                        }
                        else if(col_name == "download_status") {
                            if(val == "downloaded") {
                                current_ep.current_download_status = DownloadStatus.DOWNLOADED;
                            }
                            else {
                                current_ep.current_download_status = DownloadStatus.NOT_DOWNLOADED;
                            }
                        }
                        else if (col_name == "play_status") {
                            if(val == "played") {
                                current_ep.status = EpisodeStatus.PLAYED;
                            }  else {
                                current_ep.status = EpisodeStatus.UNPLAYED;
                            }
                            
                        }
                        else if (col_name == "latest_position") {
                            int64 position = 0;
                            if(int64.try_parse(val, out position)) {
                                current_ep.last_played_position = position;
                            }
                        }
		            }
		            
		            p.episodes.add(current_ep);
	            }

	            stmt.reset();     
            }
            
            recount_unplayed();
            set_new_badge();
        }
                
        
        /*
         * Removes a podcast from the library
         */
        public void remove_podcast(Podcast podcast) {

            string query, errmsg;
            int ec;  
            
            // Delete the podcast's episodes from the database
	        query = "DELETE FROM Episode WHERE parent_podcast_name = '%s';".printf(podcast.name.replace("'", "%27"));

	        
	        ec = db.exec (query, null, out errmsg);
	        if (ec != Sqlite.OK) {
		        stderr.printf ("Error: %d: %s\n", db.errcode (), db.errmsg ());
		        return;
	        }

            // Delete the podcast from the database
            query = "DELETE FROM Podcast WHERE name = '%s';".printf(podcast.name.replace("'", "%27"));
            ec = db.exec (query, null, out errmsg);
            
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %s\n", errmsg);
            }

            // Remove the local object as well
            podcasts.remove(podcast);
        }
        
        /*
         * Sets the latest playback position in the database for a provided episode
         *
         */
        public void set_episode_playback_position(Episode episode) {
            string query, errmsg;
            int ec;
            string title = episode.title.replace("'", "%27");
            string position_text = episode.last_played_position.to_string();


            query = """UPDATE Episode SET latest_position = '%s' WHERE title = '%s'""".printf(position_text,title);

            ec = db.exec (query, null, out errmsg);
            
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %s\n", errmsg);
            }
        }
        
/*
        public void set_launcher_progress(double progress) {
#if HAVE_LIBUNITY
            if(progress > 0.0 && progress < 1.0) {
                launcher.progress = progress;
                launcher.progress_visible = true;
            }
            else {
                launcher.progress_visible = false;
            }
#endif
        }
        
*/
        /*
         * Sets the count on the launcher to match the number of unplayed episodes (if there are
         * unplayed episodes) if libunity is enabled.
         */
        public void set_new_badge() {
#if HAVE_LIBUNITY
            launcher.count = new_episode_count;
            if(new_episode_count > 0) {
                launcher.count_visible = true;
            }
            else {
                launcher.count_visible = false;
            }
#endif

        }        

        /* 
         * Creates Vocal's config directory, establishes a new SQLite database, and creates 
         *  tables for both Podcasts and Episodes
         */
        public bool setup_library() {
                   
            
            if(settings.library_location == null) {
                settings.library_location = GLib.Environment.get_user_data_dir() +  """/vocal""";
            }
            local_library_path = settings.library_location.replace("~", GLib.Environment.get_user_data_dir());

            info("Local library path: " + local_library_path);

            // If the new local_library_path has been modified, update the setting
            if(settings.library_location != local_library_path)
            {
                settings.library_location = local_library_path;
            }

            // Create the local library
            GLib.DirUtils.create_with_parents(local_library_path, 0775);

            // Create the vocal folder if it doesn't exist
            GLib.DirUtils.create_with_parents(db_directory, 0775);

            
            // Create the database
            Sqlite.Database db;
            string error_message;
            
            int ec = Sqlite.Database.open(db_location, out db);
            if(ec != Sqlite.OK) {
                stderr.printf("Unable to create database at %s\n", db_location);
                return false;
            } else {
               
               //TODO: Make parent_podcast_name a foreign key
                string query = """
                    CREATE TABLE Podcast (
                    id                  INT,
			        name	            TEXT	PRIMARY KEY		NOT NULL,
			        feed_uri	        TEXT					NOT NULL,
			        album_art_url       TEXT,                    
			        album_art_local_uri TEXT,                    
			        description         TEXT                    NOT NULL,
			        content_type        TEXT
			     
		            ); 
		            
		            CREATE TABLE Episode (
			        title	            TEXT	PRIMARY KEY		NOT NULL,
			        parent_podcast_name TEXT                    NOT NULL,
			        parent_podcast_id   INT,                     
			        uri	                TEXT					NOT NULL,
			        local_uri           TEXT,
			        release_date        TEXT,                
                    description         TEXT,
                    latest_position     TEXT,
                    download_status     TEXT,
                    play_status         TEXT                    
		            );
		            
		            """;
	            ec = db.exec (query, null, out error_message);
	            if(ec != Sqlite.OK) {
	                stderr.printf("Unable to execute query at %s\n", db_location);
                }
                return true;
            }
        }
        
        
        
        /*
         * Writes a new episode to the database
         */
        public void write_episode_to_database(Episode episode) {

            string query, errmsg;
            int ec;
            string title, parent_podcast_name, uri, episode_description;
            title = episode.title.replace("'", "%27");
            
            parent_podcast_name = episode.parent.name.replace("'", "%27");

            uri = episode.uri;
            episode_description = episode.description.replace("'", "%27");

            
            string played_text;
            
            if(episode.status == EpisodeStatus.PLAYED) {
	            played_text = "played";
	        }
	        else {
	            played_text = "unplayed";
	        }
	        
	        string download_text;
	        if(episode.current_download_status == DownloadStatus.DOWNLOADED) {
	            download_text = "downloaded";
	        } else {
	            download_text = "not_downloaded";
	        }
            
            query = """INSERT OR REPLACE INTO Episode (title, parent_podcast_name, uri, local_uri, description, release_date, download_status, play_status) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s');"""
                .printf(title, parent_podcast_name, uri, episode.local_uri, episode_description, episode.date_released, download_text, played_text);
                
            
            ec = db.exec (query, null, out errmsg);
            
            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %s\n", errmsg);
            }
        }
    }
}
