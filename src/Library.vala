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


    public errordomain VocalLibraryError {
        ADD_ERROR, IMPORT_ERROR, MISSING_URI;
    }


    public class Library {

		// Fired when a download completes
        public signal void	download_finished(Episode episode);

        // Fired when there is an update during import
        public signal void 	import_status_changed(int current, int total, string name);

        // Fired when there is a new, new episode count
        private signal void new_episode_count_changed();

        // Fired when the queue changes
        public signal void queue_changed();

        public ArrayList<Podcast> podcasts;		// Holds all the podcasts in the library

        private Sqlite.Database db;				// The database

        private string db_location = null;
        private string vocal_config_dir = null;
        private string db_directory = null;
        private string local_library_path;

#if HAVE_LIBUNITY
        private Unity.LauncherEntry launcher;
#endif

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

        private int batch_download_count = 0;
        private bool batch_notification_needed = false;

        public Gee.ArrayList<Episode> queue = new Gee.ArrayList<Episode>();
        private GLib.List<string> podcasts_being_added = new GLib.List<string>();

        private Controller controller;

        /*
         * Constructor for the library
         */
        public Library(Controller controller) {

            this.controller = controller;

            vocal_config_dir = GLib.Environment.get_user_config_dir() + """/vocal""";
            this.db_directory = vocal_config_dir + """/database""";
            this.db_location = this.db_directory + """/vocal.db""";

            this.podcasts = new ArrayList<Podcast>();

            settings = VocalSettings.get_default_instance();

            // Set the local library path (and replace ~ with the absolute home directory if need be)
            local_library_path = settings.library_location.replace("~", GLib.Environment.get_home_dir());

#if HAVE_LIBUNITY
            launcher = Unity.LauncherEntry.get_for_desktop_id("vocal.desktop");
            launcher.count = new_episode_count;
#endif

            new_episode_count_changed.connect(set_new_badge);
            new_episode_count = 0;
        }
        
        /*
         * As Vocal gets updated,the database must grow to meet new needs.
         * This method is used to test whether certain columns exist,
         * and alters the tables as needed if they don't.
         */
        public void run_database_update_check () {
        
            if (!check_database_exists ()) {
                return;
            }
        
            info ("Performing database update check.");
            
            // Open the database
            int ec = Sqlite.Database.open (db_location, out db);
	        if (ec != Sqlite.OK) {
		        error ("Can't open database: %d: %s\n", db.errcode (), db.errmsg ());
		        return;
	        }
	        
	        // Temporarily add a dummy podcast
            string query = """INSERT OR REPLACE INTO Podcast (name, feed_uri, album_art_url, album_art_local_uri, description, content_type)
                VALUES ('%s','%s','%s','%s', '%s', '%s');""".printf("dummy", "dummy", "dummy", "dummy", "dummy", "dummy");

            string errmsg;

            ec = db.exec (query, null, out errmsg);
	        if (ec != Sqlite.OK) {
		        warning ("Error: %s\n", errmsg);
		        return;
	        }
	        
	        // Check that license is in the database (added 2018-05-06)
	        query = """SELECT license FROM Podcast WHERE name = "dummy";""";
	        errmsg = null;

            ec = db.exec (query, null, out errmsg);

            if (ec != Sqlite.OK) {
                info ("License column does not exist in podcast table. Altering table to update.");
                
                // Check that license is in the database (added 2018-05-06)
	            query = """ALTER TABLE Podcast ADD license TEXT;""";
	            errmsg = null;

                ec = db.exec (query, null, out errmsg);

                if (ec != Sqlite.OK) {
                    error ("Unable to create new license column in database.");
                } else {
                    info ("License column successfully added to database.");
                }
            }
            
            // Clean up by removing the dummy podcast
            query = """DELETE FROM Podcast WHERE name = "dummy";""";
            ec = db.exec (query, null, out errmsg);
        }


        /*
         * Returns true if the library is empty, false otherwise.
         */
        public bool empty () {
            return podcasts.size == 0;
        }


        /*
         * Adds podcasts to the library from the provided OPML file path
         */
        public async Gee.ArrayList<string> add_from_OPML(string path) {
            Gee.ArrayList<string> failed_feeds = new Gee.ArrayList<string>();
            
            SourceFunc callback = add_from_OPML.callback;
            
            ThreadFunc<void*> run = () => {
                try {
                    FeedParser feed_parser = new FeedParser();
                    string[] feeds = feed_parser.parse_feeds_from_OPML(path);
                    info("Done parsing feeds.");

                    int i = 0;
                    foreach (string feed in feeds) {
                        i++;
                        import_status_changed(i, feeds.length, feed);
                        bool temp_status = add_podcast_from_file(feed);
                        if(temp_status == false) {
                            failed_feeds.add(feed);
                            warning("Failed to add podcast from feed because add_podcast_from_file returned false. for: %s", feed);
                        }
                    }
                } catch (Error e) {
                    info("Error parsing OPML file. %s", e.message);
                }

                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);

            yield;

            return failed_feeds;
        }



        /*
         * Adds a new podcast to the library
         */
        public bool add_podcast(Podcast podcast) throws VocalLibraryError {
            info("Podcast %s being added to library.", podcast.name);

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
                if(remote_art.query_exists()) {
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
                }
            } catch(Error e) {
                error("Unable to save a local copy of the album art. %s", e.message);
            }

            // Add the podcast
            if ( write_podcast_to_database (podcast) ) {
                // Now that the podcast is in the database, add it to the local arraylist
                podcasts.add(podcast);

                foreach (Episode episode in podcast.episodes) {
                    write_episode_to_database (episode);
                }
            } else {
                warning ("failed adding podcast '%s'.", podcast.name);
            }


	        return true;

        }

		/*
		 * Adds a new podcast to the library from a given file path by parsing the file's contents
		 */
        public bool add_podcast_from_file(string path) {
        
            foreach (string s in podcasts_being_added) {
                if (s == path) {
                    info ("Podcast %s already being added.", path);
                    return false;
                }
            }
            
            foreach (Podcast p in podcasts) {
                if (p.feed_uri == path) {
                    info ("Podcast %s already in library. If you wish to re-add, remove the original first.", p.name);
                    return false;
                }
            }
            
            string uri = path;
            
            // Discover the real URI (avoid redirects)
            if(path.contains("http")) {
                uri = Utils.get_real_uri(path);
            }
            
            info("Adding podcast from: %s", uri);
            podcasts_being_added.append (path);

            FeedParser feed_parser = new FeedParser();
            Podcast new_podcast = feed_parser.get_podcast_from_file(uri);
            if(new_podcast == null) {
                warning("Failed to parse %s", uri);
                podcasts_being_added.remove (path);
                return false;
            } else {
                add_podcast(new_podcast);
                podcasts_being_added.remove (path);
                return true;
            }
        }


        /*
         * Adds a new podcast from a file, asynchronously
         */
        public async bool async_add_podcast_from_file(string path) {
        
            foreach (string s in podcasts_being_added) {
                if (s == path) {
                    info ("Podcast %s already being added.", path);
                    return false;
                }
            }
            
            foreach (Podcast p in podcasts) {
                if (p.feed_uri == path) {
                    info ("Podcast %s already in library. If you wish to re-add, remove the original first.", p.name);
                    return false;
                }
            }
            
            bool successful = true;

            SourceFunc callback = async_add_podcast_from_file.callback;

            ThreadFunc<void*> run = () => {
            
                info("Adding podcast from file: %s", path);
                podcasts_being_added.append (path);

                FeedParser parser = new FeedParser();
                try {
                    Podcast new_podcast = parser.get_podcast_from_file(path);
                    if(new_podcast == null) {
                        info("New podcast found to be null. %s", path);
                        successful = false;
                    } else {
                        info("Async Adding %s", new_podcast.name);
                        add_podcast(new_podcast);
                    }
                } catch (Error e) {
                    error("Failed to add podcast: %s", e.message);
                    successful = false;
                }
                
                podcasts_being_added.remove (path);

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
        public async Gee.ArrayList<Episode> check_for_updates() {
            SourceFunc callback = check_for_updates.callback;
            Gee.ArrayList<Episode> new_episodes = new Gee.ArrayList<Episode>();

            FeedParser parser = new FeedParser();

            ThreadFunc<void*> run = () => {
                foreach(Podcast podcast in podcasts) {
                    int added = -1;
                    if (podcast.feed_uri != null && podcast.feed_uri.length > 4) {
                        info("updating feed %s", podcast.feed_uri);
                        
                        try {
                            added = parser.update_feed(podcast);
                        } catch(Error e) {
                            warning("Failed to update feed for podcast: %s. %s", podcast.name, e.message);
                            continue;
                        }
                    }

                    while(added > 0) {
                        int index = podcast.episodes.size - added;

                        // Add the new episode to the arraylist in case it needs to be downloaded later
                        new_episodes.add(podcast.episodes[index]);

                        write_episode_to_database(podcast.episodes[index]);
                        added--;
                    }
                    
                    if (added == -1) {
                        critical ("Unable to update podcast due to missing feed URL: " + podcast.name);
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

            // Clear the fields in the episode
            e.current_download_status = DownloadStatus.NOT_DOWNLOADED;
            e.local_uri = null;

            write_episode_to_database (e);
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
                string path = library_location + "/%s/%s".printf(episode.parent.name.replace("%27", "'").replace("%", "_"), remote_file.get_basename());
                GLib.File local_file = GLib.File.new_for_path(path);

                detail_box = new DownloadDetailBox(episode);
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
                mark_episode_as_downloaded(episode);


            } catch (Error e) {
            }

            if(batch_download_count > 0) {
                batch_notification_needed = true;
            }
            batch_download_count++;

            return detail_box;
        }

        /*
         * Adds an episode to the queue
         */
        public void enqueue_episode(Episode e) {
            if(!queue.contains(e)){
                queue.add(e);
                queue_changed();
            }
        }

        /*
         * Returns the next episode to be played in the queue
         */
        public Episode? get_next_episode_in_queue() {
            if(queue.size > 0) {
                Episode temp =  queue[0];
                queue.remove(queue[0]);
                queue_changed();
                return temp;
            } else {
                return null;
            }
        }

        /*
         * Moves an episode higher up in the queue so it will be played quicker
         */
        public void move_episode_up_in_queue(Episode e) {
            int i = 0;
            bool match = false;
            while(i < queue.size) {
                match = (e == queue[i]);
                if(match && i-1 >= 0) {
                    Episode old = queue[i-1];
                    queue[i-1] = queue[i];
                    queue[i] = old;
                    queue_changed();
                    return;
                }
                i++;
            }

        }

        /*
         * Moves an episode down in the queue to give other episodes higher priority
         */
        public void move_episode_down_in_queue(Episode e) {
            int i = 0;
            bool match = false;
            while(i < queue.size) {
                match = (e == queue[i]);
                if(match && i+1 < queue.size) {
                    Episode old = queue[i+1];
                    queue[i+1] = queue[i];
                    queue[i] = old;
                    queue_changed();
                    return;
                }
                i++;
            }
        }


        /*
         * Updates the queue by moving an episode in the old position to the new position
         */
        public void update_queue(int oldPos, int newPos) {
            int i;

            if(oldPos < newPos){
                for(i = oldPos; i < newPos; i++) {
                    swap(queue, i, i+1);
                }
            } else {
                for(i = oldPos; i > newPos; i--) {
                    swap(queue, i, i-1);
                }
            }
        }

        /*
         * Used by update_queue to swap episodes in the queue.
         */
        private void swap(Gee.ArrayList<Episode> q, int a, int b) {
            Episode tmp = q[a];
            q[a] = q[b];
            q[b] = tmp;
        }


        /*
         * Removes an episode from the queue altogether
         */
        public void remove_episode_from_queue(Episode e) {
            foreach(Episode ep in queue) {
                if(e == ep) {
                    queue.remove(e);
                    queue_changed();
                    return;
                }
            }
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

            episode.current_download_status = DownloadStatus.DOWNLOADED;
            write_episode_to_database (episode);

        }

        /*
         * Marks an episode as played in the database
         */
        public void mark_episode_as_played(Episode episode) {

            if(episode == null)
                error("Episode null!");

            episode.status = EpisodeStatus.PLAYED;
            write_episode_to_database (episode);
        }

        /*
         * Marks an episode as unplayed in the database
         */
        public void mark_episode_as_unplayed(Episode episode) {

            episode.status = EpisodeStatus.UNPLAYED;
            write_episode_to_database (episode);

        }

        /*
         * Notifies the user that a download has completed successfully
         */
        public void on_successful_download(string episode_title, string parent_podcast_name) {

            batch_download_count--;
            try {
                recount_unplayed();
                set_new_badge();

#if HAVE_LIBNOTIFY

            if(!batch_notification_needed) {
                string message = _("'%s' from '%s' has finished downloading.").printf(episode_title.replace("%27", "'"), parent_podcast_name.replace("%27","'"));
                var notification = new Notify.Notification(_("Episode Download Complete"), message, null);
                if(!controller.window.focus_visible)
                    notification.show();
            } else {
                if(batch_download_count == 0) {
                    var notification = new Notify.Notification(_("Downloads Complete"), _("New episodes have been downloaded."), "vocal");
                    batch_notification_needed = false;
                    if(!controller.window.focus_visible)
                        notification.show();
                }
            }

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

            } catch(Error e) {
                error("%s", e.message);
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
		        warning("%d: %s\n", db.errcode (), db.errmsg ());
		        return;
	        }

	        // Use the prepared statement:

	        while (stmt.step () == Sqlite.ROW) {
	            Podcast current = podcast_from_row(stmt);
		        podcasts.add(current);
	        }

	        stmt.reset();


	        // Repeat the process with the episodes

	        foreach(Podcast podcast in podcasts) {

	            prepared_query_str = "SELECT * FROM Episode WHERE parent_podcast_name = '%s' ORDER BY rowid ASC".printf(podcast.name);
	            ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
	            if (ec != Sqlite.OK) {
		            stderr.printf ("Error: %d: %s\n", db.errcode (), db.errmsg ());
		            return;
	            }

	            while (stmt.step () == Sqlite.ROW) {
                    Episode episode = episode_from_row(stmt);
                    episode.parent = podcast;

		            podcast.episodes.add(episode);
	            }

	            stmt.reset();
            }

            recount_unplayed();
            set_new_badge();
        }

        public ArrayList<Podcast> find_matching_podcasts(string term) {

            ArrayList<Podcast> matches = new ArrayList<Podcast>();

            prepare_database();

            Sqlite.Statement stmt;

            string prepared_query_str = "SELECT * FROM Podcast WHERE name LIKE ? ORDER BY name";
            int ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
            ec = stmt.bind_text(1, term, -1, null);
            if (ec != Sqlite.OK) {
                warning("%d: %s\n", db.errcode (), db.errmsg ());
                return matches;
            }

            // Use the prepared statement:

            int cols = stmt.column_count ();
            while (stmt.step () == Sqlite.ROW) {
                Podcast current = podcast_from_row(stmt);

                matches.add(current);
            }

            stmt.reset();
            return matches;
        }

        public ArrayList<Episode> find_matching_episodes(string term) {

            ArrayList<Episode> matches = new ArrayList<Episode>();

            prepare_database();

            Sqlite.Statement stmt;

            string prepared_query_str = "SELECT * FROM Episode WHERE title LIKE ? ORDER BY title";
            int ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
            ec = stmt.bind_text(1, "%" + term + "%", -1, null);
            if (ec != Sqlite.OK) {
                warning("%d: %s\n".printf(db.errcode (), db.errmsg ()));
                return matches;
            }

            // Use the prepared statement:

            int cols = stmt.column_count ();
            while (stmt.step () == Sqlite.ROW) {

                Episode current_ep = episode_from_row(stmt);

                //Add the new episode
                matches.add(current_ep);
                
            }

            stmt.reset();
            return matches;
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

        public Gee.ArrayList<Podcast>? search_by_term(string term) {

            prepare_database();

            Sqlite.Statement stmt;

            var search_pods = new Gee.ArrayList<Podcast>();

            string prepared_query_str = "SELECT * FROM Podcast WHERE name='%s' ORDER BY name".printf(term);
            int ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
            if (ec != Sqlite.OK) {
                warning("%d: %s\n".printf(db.errcode (), db.errmsg ()));
                return null;
            }

            // Use the prepared statement:

            while (stmt.step () == Sqlite.ROW) {
                Podcast current = podcast_from_row(stmt);

                search_pods.add(current);
            }

            stmt.reset();

            return search_pods;
        }

        public Episode episode_from_row(Statement stmt) {
            Episode episode = new Episode();

            for (int i = 0; i < stmt.column_count(); i++) {
                string col_name = stmt.column_name (i) ?? "<none>";
                string val = stmt.column_text (i) ?? "<none>";

                if(col_name == "title") {
                    episode.title = val;
                }
                else if(col_name == "description") {
                    episode.description = val;
                }
                else if (col_name == "uri") {
                    episode.uri = val;
                }
                else if (col_name == "local_uri") {
                    if(val != "(null)")
                        episode.local_uri = val;
                }
                else if (col_name == "release_date") {
                    episode.date_released = val;
                    episode.set_datetime_from_pubdate();
                }
                else if(col_name == "download_status") {
                    if(val == "downloaded") {
                        episode.current_download_status = DownloadStatus.DOWNLOADED;
                    }
                    else {
                        episode.current_download_status = DownloadStatus.NOT_DOWNLOADED;
                    }
                }
                else if (col_name == "play_status") {
                    if(val == "played") {
                        episode.status = EpisodeStatus.PLAYED;
                    }  else {
                        episode.status = EpisodeStatus.UNPLAYED;
                    }
                }
                else if (col_name == "latest_position") {
                    double position = 0;
                    if(double.try_parse(val, out position)) {
                        episode.last_played_position = position;
                    }
                }
                else if(col_name == "parent_podcast_name") {
                    episode.parent = new Podcast.with_name(val);
                }
            }

            return episode;
        }

        public Podcast podcast_from_row(Statement stmt) {
            Podcast podcast = new Podcast();

            for (int i = 0; i < stmt.column_count(); i++) {
                string col_name = stmt.column_name (i) ?? "<none>";
                string val = stmt.column_text (i) ?? "<none>";

                if(col_name == "name") {
                    podcast.name = val;
                }
                else if(col_name == "feed_uri") {
                    podcast.feed_uri = val;
                }
                else if (col_name == "album_art_url") {
                    podcast.remote_art_uri = val;
                }
                else if (col_name == "album_art_local_uri") {
                    podcast.local_art_uri = val;
                }
                else if(col_name == "description") {
                    podcast.description = val;
                }
                else if (col_name == "content_type") {
                    if(val == "audio") {
                        podcast.content_type = MediaType.AUDIO;
                    }
                    else if(val == "video") {
                        podcast.content_type = MediaType.VIDEO;
                    }
                    else {
                        podcast.content_type = MediaType.UNKNOWN;
                    }
                } else if (col_name == "license") {
                    if (val == "cc") {
                        podcast.license = License.CC;
                    } else if (val == "public") {
                        podcast.license = License.PUBLIC;
                    } else if (val == "reserved") {
                        podcast.license = License.RESERVED;
                    } else {
                        podcast.license = License.UNKNOWN;
                    }
                }
            }

            return podcast;
        }

        /*
         * Sets the latest playback position in the database for a provided episode
         * The `last_played_position` property must have already been updated in the episode object.
         */
        public void set_episode_playback_position(Episode episode) {
            write_episode_to_database (episode);
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
        
        public void set_new_local_album_art(string path_to_local_file, Podcast p) {
            
            // Copy the file
            GLib.File current_file = GLib.File.new_for_path(path_to_local_file);

            InputStream input_stream = current_file.read();

            string path = settings.library_location + "/%s/cover.jpg".printf(p.name.replace("%27", "'").replace("%", "_"));
            GLib.File local_file = GLib.File.new_for_path(path);

            current_file.copy_async(local_file, FileCopyFlags.OVERWRITE, Priority.DEFAULT, null, null);
            
            // Set the new file location in the database
            string query, errmsg;
            int ec;

            query = """UPDATE Podcast SET album_art_local_uri = '%s' WHERE name = '%s'""".printf(local_file.get_uri(),p.name);

            ec = db.exec (query, null, out errmsg);

            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %s\n", errmsg);
            }
            
            // Set the new file location for the podcast object
            p.local_art_uri = local_file.get_uri();
            
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

            // If the new local_library_path has been modified, update the setting
            if(settings.library_location != local_library_path)
            {
                settings.library_location = local_library_path;
            }

            // Create the local library
            GLib.DirUtils.create_with_parents(local_library_path, 0775);

            // Create the vocal folder if it doesn't exist
            GLib.DirUtils.create_with_parents(db_directory, 0775);


            prepare_database ();

            string query = """
              CREATE TABLE Podcast (
                id                  INT,
                name                TEXT    PRIMARY KEY     NOT NULL,
                feed_uri            TEXT                    NOT NULL,
                album_art_url       TEXT,
                album_art_local_uri TEXT,
                description         TEXT                    NOT NULL,
                content_type        TEXT,
                license             TEXT
              );

              CREATE TABLE Episode (
                title               TEXT    PRIMARY KEY     NOT NULL,
                parent_podcast_name TEXT                    NOT NULL,
                parent_podcast_id   INT,
                uri                 TEXT                    NOT NULL,
                local_uri           TEXT,
                release_date        TEXT,
                description         TEXT,
                latest_position     TEXT,
                download_status     TEXT,
                play_status         TEXT
              );
            """;

            int ec = db.exec (query, null);
            if (ec != Sqlite.OK) {
                error ("unable to create database %d: %s", db.errcode (), db.errmsg ());
            }
            return true;

        }


        /*
         * INSERT/REPLACE a Podcast in the database
         */
        public bool write_podcast_to_database(Podcast podcast) {

            string content_type_text;
            if (podcast.content_type == MediaType.AUDIO) {
                content_type_text = "audio";
            } else if (podcast.content_type == MediaType.VIDEO) {
                content_type_text = "video";
            } else {
                content_type_text = "unknown";
            }

            string license_text;
            if (podcast.license == License.CC) {
                license_text = "cc";
            } else if (podcast.license == License.PUBLIC) {
                license_text = "public";
            } else if (podcast.license == License.RESERVED) {
                license_text = "reserved";
            } else {
                license_text = "unknown";
            }

            string query = "INSERT OR REPLACE INTO Podcast " +
            " (name, feed_uri, album_art_url, album_art_local_uri, description, content_type, license) " +
            " VALUES (?1,?2, ?3, ?4, ?5, ?6, ?7);";


            Sqlite.Statement stmt;
            int ec = db.prepare_v2 (query, query.length, out stmt);

            if (ec != Sqlite.OK) {
                warning ("Unable to prepare podcast update statement. %d: %s", db.errcode (), db.errmsg ());
                return false;
            }
            /* This is here for compatibility. Escaping the name should not be necessary
             * but is left to remain consitent with existing db entries since the name
             * is currently used as the key field. */
            string name = podcast.name.replace("'", "%27");

            stmt.bind_text (1, name);
            stmt.bind_text (2, podcast.feed_uri);
            stmt.bind_text (3, podcast.remote_art_uri);
            stmt.bind_text (4, podcast.local_art_uri);
            stmt.bind_text (5, podcast.description);
            stmt.bind_text (6, content_type_text);
            stmt.bind_text (7, license_text);

            ec = stmt.step ();

            if (ec != Sqlite.DONE) {
                warning ("Unable to insert/update podcast. %d: %s", db.errcode (), db.errmsg ());
                return false;
            }

            return true;
        }



        /*
         * Insert/Replace an episode in the database
         */
        public bool write_episode_to_database(Episode episode) {

            string query = "INSERT OR REPLACE INTO Episode " +
                           " (title, parent_podcast_name, uri, local_uri, description, release_date, download_status, play_status, latest_position) " +
                           " VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9);";

            Sqlite.Statement stmt;
            int ec = db.prepare_v2 (query, query.length, out stmt);

            if (ec != Sqlite.OK) {
                warning ("Unable to prepare episode update statement. %d: %s", db.errcode (), db.errmsg ());
                return false;
            }

            /* This is here for compatibility. Escaping these values should not be necessary
             * but is done to remain consitent with existing db entries since the title
             * and podcast name are currently used as key fields. */
            string title = episode.title.replace("'", "%27");
            string parent_podcast_name = episode.parent.name.replace("'", "%27");

            // convert enums to text representations.
            string played_text = (episode.status == EpisodeStatus.PLAYED) ? "played" : "unplayed";
            string download_text = (episode.current_download_status == DownloadStatus.DOWNLOADED) ? "downloaded" : "not_downloaded";

            stmt.bind_text (1, title);
            stmt.bind_text (2, parent_podcast_name);
            stmt.bind_text (3, episode.uri);
            stmt.bind_text (4, episode.local_uri);
            stmt.bind_text (5, episode.description);
            stmt.bind_text (6, episode.date_released);
            stmt.bind_text (7, download_text);
            stmt.bind_text (8, played_text);
            stmt.bind_text (9, episode.last_played_position.to_string ());

            ec = stmt.step ();

            if (ec != Sqlite.DONE) {
                warning ("Unable to insert/update episode. %d: %s", db.errcode (), db.errmsg ());
                return false;
            }

            return true;
        }
    }
}
