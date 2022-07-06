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
using Gst;
using GLib;
using Sqlite;


namespace Vocal {


    public errordomain VocalLibraryError {
        ADD_ERROR, IMPORT_ERROR, MISSING_URI;
    }


    public class Library {

        // Fired when a download completes
        public signal void download_finished (Episode episode);

        // Fired when there is an update during import
        public signal void import_status_changed (int current, int total, string name, bool from_sync);

        // Fired when there is a new, new episode count
        private signal void new_episode_count_changed ();

        // Fired when the queue changes
        public signal void queue_changed ();

        // Fired after library has been refilled
        public signal void library_ready ();

        public ArrayList<Podcast> podcasts;        // Holds all the podcasts in the library

        private Sqlite.Database db;                // The database

        private string db_location = null;
        private string vocal_config_dir = null;
        private string db_directory = null;
        private string local_library_path;

        private VocalSettings settings;            // Vocal's settings

        Episode downloaded_episode = null;

        private int _new_episode_count;
        public int new_episode_count {
            get { return _new_episode_count; }

            set {
                _new_episode_count = value;
                new_episode_count_changed ();
            }
        }

        private int batch_download_count = 0;
        private bool batch_notification_needed = false;

        public Gee.ArrayList<Episode> queue = new Gee.ArrayList<Episode> ();
        private GLib.List<string> podcasts_being_added = new GLib.List<string> ();

        private Vocal.Application controller;
        public string pending_import = null;

        /*
         * Constructor for the library
         */
        public Library (Vocal.Application controller) {

            this.controller = controller;

            vocal_config_dir = GLib.Environment.get_user_config_dir ();
            local_library_path = GLib.Environment.get_user_data_dir ();

            this.db_directory = vocal_config_dir + """/database""";
            this.db_location = this.db_directory + """/vocal.db""";

            this.podcasts = new ArrayList<Podcast> ();

            settings = VocalSettings.get_default_instance ();

            new_episode_count = 0;
        }

        /*
         * As Vocal gets updated,the database must grow to meet new needs.
         * This method is used to test whether certain columns exist,
         * and alters the tables as needed if they don't.
         */
        public void run_database_update_check () {

            if ( ! check_database_exists ()) {
                return;
            }

            prepare_database ();

            int current_db_version = get_db_version ();

            info ("Performing database update check. Current version: %d", current_db_version);

            // Check that license is in the database (added 2018-05-06)
            string query = """SELECT license FROM Podcast WHERE name = "dummy";""";
            string errmsg = null;

            int ec = db.exec (query, null, out errmsg);

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

            if (current_db_version < 1) {
                info ("Updating DB schema to v1 ...");

                // Backup existing data before creating schema at current level.
                // Load podcasts here since the export expects the library to be loaded.
                Sqlite.Statement stmt;
                query = "SELECT * FROM Podcast ORDER BY name";
                ec = db.prepare_v2 (query, query.length, out stmt);

                while (stmt.step () == Sqlite.ROW) {
                    Podcast current = podcast_from_row (stmt);
                    podcasts.add (current);
                }

                stmt.reset ();

                string export_name = "vocal_export-%s.xml".printf (new GLib.DateTime.now_utc ().format ("%FT%TZ"));
                string export_path = Path.build_filename(db_directory, export_name);
                info ("exporting existing subscriptions to <%s>.", export_path);
                export_to_OPML (export_path);

                podcasts.clear ();

                this.pending_import = export_path; // save location for later import.

                // Create backup of existing db tables.
                query = """
                  BEGIN TRANSACTION;

                  ALTER TABLE Podcast RENAME TO Podcast_V0;
                  ALTER TABLE Episode RENAME TO Episode_V0;

                  END TRANSACTION;
                """;

                ec = db.exec (query, null);
                if (ec != Sqlite.OK) {
                    error ("Rename of existing tables failed! (%d) %s", db.errcode (), db.errmsg ());
                }

                create_db_schema ();

                info ("DB update finished.");

                current_db_version = get_db_version ();
            }

            assert (current_db_version == 1);
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
        public async Gee.ArrayList<string> add_from_OPML (string path, bool? raw_data = false, bool from_sync) {
            Gee.ArrayList<string> failed_feeds = new Gee.ArrayList<string> ();

            GLib.Idle.add(add_from_OPML.callback);

            try {
                FeedParser feed_parser = new FeedParser ();
                string[] feeds = feed_parser.parse_feeds_from_OPML (path, raw_data);
                info ("Done parsing feeds.");

                int i = 0;
                foreach (string feed in feeds) {
                    i++;
                    import_status_changed (i, feeds.length, feed, from_sync);
                    bool temp_status = add_podcast_from_file (feed);
                    if (temp_status == false) {
                        failed_feeds.add (feed);
                        warning ("Failed to add podcast from feed because add_podcast_from_file returned false. for: %s", feed);
                    }
                }
            } catch (Error e) {
                info ("Error parsing OPML file. %s", e.message);
            }



            yield;

            return failed_feeds;
        }



        /*
         * Adds a new podcast to the library
         */
        public bool add_podcast (Podcast podcast) throws VocalLibraryError {
            info ("Podcast %s being added to library.", podcast.name);

            // Set all but the most recent episode as played on initial add to library
            if (podcast.episodes.size > 0) {
                for (int i = 0; i < podcast.episodes.size-1; i++) {
                    podcast.episodes[i].status = EpisodeStatus.PLAYED;
                }
            }

            string podcast_path = local_library_path + "/%s".printf (podcast.name.replace ("%27", "'").replace ("%", "_"));
            print("Podcast path: " + podcast_path + "\n");

            // Create a directory for downloads and artwork caching in the local library
            GLib.DirUtils.create_with_parents (podcast_path, 0775);

            ImageCache image_cache = new ImageCache ();
            image_cache.get_image_async.begin (podcast.remote_art_uri, (obj, res) => {
                image_cache.get_image_async.end (res);
            });

            // Add the podcast
            if (write_podcast_to_database (podcast)) {
                // Now that the podcast is in the database, add it to the local arraylist
                podcasts.add (podcast);

                foreach (Episode episode in podcast.episodes) {
                    episode.podcast_uri = podcast.feed_uri;
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
        public bool add_podcast_from_file (string path) {

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
            if (path.contains ("http")) {
                uri = Utils.get_real_uri (path);
            }

            info ("Adding podcast from: %s", uri);
            podcasts_being_added.append (path);

            FeedParser feed_parser = new FeedParser ();
            Podcast new_podcast = null;
            try {
                new_podcast = feed_parser.get_podcast_from_file (uri);
            } catch (Error e) {
                warning (e.message);
            }

            if (new_podcast == null) {
                warning ("Failed to parse %s", uri);
                podcasts_being_added.remove (path);
                return false;
            } else {
                try {
                    add_podcast (new_podcast);
                    podcasts_being_added.remove (path);
                } catch (Error e) {
                    warning (e.message);
                }
                return true;
            }
        }


        /*
         * Adds a new podcast from a file, asynchronously
         */
        public async bool async_add_podcast_from_file (string path) {

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

            bool successful = false;

            GLib.Idle.add(async_add_podcast_from_file.callback);

            info ("Adding podcast from file: %s", path);
            podcasts_being_added.append (path);

            FeedParser parser = new FeedParser ();

            try {
                Podcast new_podcast = parser.get_podcast_from_file (path);

                if (new_podcast == null) {
                    info ("New podcast found to be null. %s", path);
                    successful = false;
                } else {
                    info ("Async Adding %s", new_podcast.name);
                    successful = true;
                    add_podcast (new_podcast);
                }
            } catch (Error e) {
                error ("Failed to add podcast: %s", e.message);
            }

            podcasts_being_added.remove (path);

            yield;

            return successful;
        }

        /*
         * Checks library for downloaded episodes that are played and over a week old
         */
        public async void autoclean_library () {

            GLib.Idle.add(autoclean_library.callback);

            // Create a new DateTime that is the current date and then subtract one week
            GLib.DateTime week_ago = new GLib.DateTime.now_utc ();
            week_ago = week_ago.add_weeks(-1);

            foreach (Podcast p in podcasts) {
                foreach (Episode e in p.episodes) {

                    // If e is downloaded, played, and more than a week old
                    if (e.current_download_status == DownloadStatus.DOWNLOADED &&
                        e.status == EpisodeStatus.PLAYED && e.datetime_released.compare (week_ago) == -1) {

                        // Delete the episode. Skip checking for an existing file, the delete_episode method will do that automatically
                        info ("Episode %s is more than a week old. Deleting.".printf (e.title));
                        delete_local_episode (e);
                    }
                }
            }

            yield;
        }

        /*
         * Checks to see if the local database file exists
         */
        public bool check_database_exists () {
            File file = File.new_for_path (db_location);
            return file.query_exists ();
        }

        /*
         * Checks each feed in the library to see if new episodes are available
         */
        public async Gee.ArrayList<Episode> check_for_updates () {
            GLib.Idle.add(check_for_updates.callback);
            Gee.ArrayList<Episode> new_episodes = new Gee.ArrayList<Episode> ();

            FeedParser parser = new FeedParser ();

            foreach (Podcast podcast in podcasts) {
                int added = -1;
                if (podcast.feed_uri != null && podcast.feed_uri.length > 4) {
                    info ("updating feed %s", podcast.feed_uri);

                    try {
                        added = parser.update_feed (podcast);
                    } catch (Error e) {
                        warning ("Failed to update feed for podcast: %s. %s", podcast.name, e.message);
                        continue;
                    }
                }

                while (added > 0) {
                    int index = podcast.episodes.size - added;

                    // Add the new episode to the arraylist in case it needs to be downloaded later
                    new_episodes.add (podcast.episodes[index]);

                    write_episode_to_database (podcast.episodes[index]);
                    added--;
                }

                if (added == -1) {
                    critical ("Unable to update podcast due to missing feed URL: " + podcast.name);
                }
            }


            yield;

            return new_episodes;
        }

        /*
         * Deletes the local media file for an episode
         */
        public void delete_local_episode (Episode e) {

            // First check that the file exists
            GLib.File local = GLib.File.new_for_path (e.local_uri);
            if (local.query_exists ()) {

                // Delete the file
                try {
                    local.delete ();
                } catch (Error e) {
                    warning (e.message);
                }
            }

            // Clear the fields in the episode
            e.current_download_status = DownloadStatus.NOT_DOWNLOADED;
            e.local_uri = null;

            write_episode_to_database (e);
            recount_unplayed ();
        }


        /*
         * Downloads a podcast to the local directory and creates a DownloadDetailBox that is useful
         * for displaying download progress information later
         */
        public DownloadDetailBox? download_episode (Episode episode) {

            // Check to see if the episode has already been downloaded
            if (episode.current_download_status == DownloadStatus.DOWNLOADED) {
                warning ("Error. Episode %s is already downloaded.\n", episode.title);
                return null;
            }

            // Create a file object for the remotely hosted file
            GLib.File remote_file = GLib.File.new_for_uri (episode.uri);

            bool remote_exists = remote_file.query_exists ();
            if(remote_exists) {

            }

            DownloadDetailBox detail_box = null;

            // Set the path of the new file and create another object for the local file
            string path = local_library_path + "/%s/%s".printf (episode.parent.name.replace ("%27", "'").replace ("%", "_"), remote_file.get_basename ());

            GLib.File local_file = GLib.File.new_for_path (path);

            detail_box = new DownloadDetailBox (episode);
            detail_box.download_has_completed_successfully.connect (on_successful_download);
            FileProgressCallback callback = detail_box.download_delegate;
            GLib.Cancellable cancellable = new GLib.Cancellable ();

            detail_box.cancel_requested.connect (() => {
                cancellable.cancel ();
                bool exists = local_file.query_exists ();
                if (exists) {
                    try {
                        local_file.delete ();
                    } catch (Error e) {
                        stderr.puts ("Unable to delete file.\n");
                    }
                }

            });

            remote_file.copy_async.begin (local_file, FileCopyFlags.OVERWRITE, 0, cancellable, callback, (obj, res) => {
	            try {
		            bool success = remote_file.copy_async.end (res);
		            if(success) {
                        // Set the episode's local uri to the new path
                        mark_episode_as_downloaded (episode);
                    }
	            } catch (Error e) {
		            warning ("Error: %s\n", e.message);
	            }

            });

            if (batch_download_count > 0) {
                batch_notification_needed = true;
            }
            batch_download_count++;

            return detail_box;
        }

        /*
         * Adds an episode to the queue
         */
        public void enqueue_episode (Episode e) {
            if (!queue.contains (e)) {
                queue.add (e);
                queue_changed ();
            }
        }

        /*
         * Returns the next episode to be played in the queue
         */
        public Episode? get_next_episode_in_queue () {
            if (queue.size > 0) {
                Episode temp = queue[0];
                queue.remove (queue[0]);
                queue_changed ();
                return temp;
            } else {
                return null;
            }
        }

        /*
         * Moves an episode higher up in the queue so it will be played quicker
         */
        public void move_episode_up_in_queue (Episode e) {
            int i = 0;
            bool match = false;
            while (i < queue.size) {
                match = (e == queue[i]);
                if (match && i-1 >= 0) {
                    Episode old = queue[i-1];
                    queue[i-1] = queue[i];
                    queue[i] = old;
                    queue_changed ();
                    return;
                }
                i++;
            }

        }

        /*
         * Moves an episode down in the queue to give other episodes higher priority
         */
        public void move_episode_down_in_queue (Episode e) {
            int i = 0;
            bool match = false;
            while (i < queue.size) {
                match = (e == queue[i]);
                if (match && i+1 < queue.size) {
                    Episode old = queue[i+1];
                    queue[i+1] = queue[i];
                    queue[i] = old;
                    queue_changed ();
                    return;
                }
                i++;
            }
        }


        /*
         * Updates the queue by moving an episode in the old position to the new position
         */
        public void update_queue (int oldPos, int newPos) {
            int i;

            if (oldPos < newPos) {
                for (i = oldPos; i < newPos; i++) {
                    swap (queue, i, i+1);
                }
            } else {
                for (i = oldPos; i > newPos; i--) {
                    swap (queue, i, i-1);
                }
            }
        }

        /*
         * Used by update_queue to swap episodes in the queue.
         */
        private void swap (Gee.ArrayList<Episode> q, int a, int b) {
            Episode tmp = q[a];
            q[a] = q[b];
            q[b] = tmp;
        }


        /*
         * Removes an episode from the queue altogether
         */
        public void remove_episode_from_queue (Episode e) {
            foreach (Episode ep in queue) {
                if (e == ep) {
                    queue.remove (e);
                    queue_changed ();
                    return;
                }
            }
        }


        /*
         * Exports the current podcast subscriptions to a file at the provided path
         */
        public void export_to_OPML (string path) {
            File file = File.new_for_path (path);
            try {
                GLib.DateTime now = new GLib.DateTime.now (new TimeZone.local ());
                string header = """<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
<head>
    <title>Vocal Subscriptions Export</title>
    <dateCreated>%s</dateCreated>
    <dateModified>%s</dateModified>
</head>
<body>
    """.printf (now.to_string (), now.to_string ());
                FileIOStream stream = file.create_readwrite (FileCreateFlags.REPLACE_DESTINATION);
                stream.output_stream.write (header.data);

                string output_line;

                foreach (Podcast p in podcasts) {

                    output_line =
    """<outline text="%s" type="rss" xmlUrl="%s"/>
    """.printf (p.name.replace ("\"", "'").replace ("&", "and"), p.feed_uri);
                    stream.output_stream.write (output_line.data);
                }

                const string footer = """
</body>
</opml>
""";

                stream.output_stream.write (footer.data);
            } catch (Error e) {
                warning ("Error: %s\n", e.message);
            }
        }

        /*
         * Marks all episodes in a given podcast as played
         */
        public void mark_all_episodes_as_played (Podcast highlighted_podcast) {
            foreach (Episode episode in highlighted_podcast.episodes) {
                mark_episode_as_played (episode);
            }
        }

        /*
         * Marks an episode as downloaded in the database
         */
        public void mark_episode_as_downloaded (Episode episode) {
            episode.current_download_status = DownloadStatus.DOWNLOADED;
            write_episode_to_database (episode);
        }

        /*
         * Marks an episode as played in the database
         */
        public void mark_episode_as_played (Episode episode) {

            if (episode == null)
                error ("Episode null!");

            episode.status = EpisodeStatus.PLAYED;
            write_episode_to_database (episode);
        }

        /*
         * Marks an episode as unplayed in the database
         */
        public void mark_episode_as_unplayed (Episode episode) {

            episode.status = EpisodeStatus.UNPLAYED;
            write_episode_to_database (episode);

        }

        /*
         * Notifies the user that a download has completed successfully
         */
        public void on_successful_download (string episode_title, string parent_podcast_name) {

            batch_download_count--;

            recount_unplayed ();

            // Find the episode in the library
            downloaded_episode = null;
            bool found = false;

            // TODO: the following can be very slow for large podcasts/databases, should be done in sql.

            foreach (Podcast podcast in podcasts) {
                if (!found) {
                    if (parent_podcast_name == podcast.name) {
                        foreach (Episode episode in podcast.episodes) {
                            if (episode_title == episode.title) {
                                downloaded_episode = episode;
                                found = true;
                            }
                        }

                    }
                }
            }

            // If the episode was found (and it should have been), mark as downloaded and write to database
            if (downloaded_episode != null) {
                downloaded_episode.current_download_status = DownloadStatus.DOWNLOADED;
                mark_episode_as_downloaded (downloaded_episode);
            }
        }

        /*
         * Opens the database and prepares for queries
         */
        private int prepare_database () {

            assert (db_location != null);

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
        public void recount_unplayed () {
            new_episode_count = 0;
            foreach (Podcast p in podcasts) {
                foreach (Episode e in p.episodes) {
                    if (e.status == EpisodeStatus.UNPLAYED) {
                        new_episode_count++;
                    }
                }
            }
        }

        /*
         * Refills the local library from the contents stored in the database
         */
        public async void refill_library () {

            GLib.Idle.add(this.refill_library.callback);

            podcasts.clear ();
            prepare_database ();

            Sqlite.Statement stmt;

            string prepared_query_str = "SELECT * FROM Podcast ORDER BY name";
            int ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
            if (ec != Sqlite.OK) {
                warning ("%d: %s\n", db.errcode (), db.errmsg ());
                return;
            }

            // Use the prepared statement:

            while (stmt.step () == Sqlite.ROW) {
                Podcast current = podcast_from_row (stmt);
                podcasts.add (current);
            }

            stmt.reset ();


            // Repeat the process with the episodes
            // TODO: instead of running a separate sql query for each podcast all episodes
            //       can be loaded in single statement.
            foreach (Podcast podcast in podcasts) {

                prepared_query_str = "SELECT e.*, p.name as parent_podcast_name
                                      FROM Episode e
                                      LEFT JOIN Podcast p on p.feed_uri = e.podcast_uri
                                      WHERE podcast_uri = '%s'
                                      ORDER BY e.rowid ASC".printf (podcast.feed_uri);
                ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
                if (ec != Sqlite.OK) {
                    warning ("Error: %d: %s\n", db.errcode (), db.errmsg ());
                    return;
                }

                while (stmt.step () == Sqlite.ROW) {
                    Episode episode = episode_from_row (stmt);
                    episode.parent = podcast;

                    podcast.episodes.add (episode);
                }

                stmt.reset ();
            }

            recount_unplayed ();

            yield;

            library_ready();
        }

        public ArrayList<Podcast> find_matching_podcasts (string term) {

            ArrayList<Podcast> matches = new ArrayList<Podcast> ();

            prepare_database ();

            Sqlite.Statement stmt;

            string prepared_query_str = "SELECT * FROM Podcast WHERE name LIKE ? ORDER BY name";
            int ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
            ec = stmt.bind_text (1, "%" + term + "%", -1);
            if (ec != Sqlite.OK) {
                warning ("%d: %s\n", db.errcode (), db.errmsg ());
                return matches;
            }

            // Use the prepared statement:
            while (stmt.step () == Sqlite.ROW) {
                Podcast current = podcast_from_row (stmt);

                matches.add (current);
            }

            stmt.reset ();
            return matches;
        }

        public ArrayList<Episode> find_matching_episodes (string term) {

            ArrayList<Episode> matches = new ArrayList<Episode> ();

            prepare_database ();

            Sqlite.Statement stmt;

            string prepared_query_str = "SELECT * FROM Episode WHERE title LIKE ? ORDER BY title";
            int ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
            ec = stmt.bind_text (1, "%" + term + "%", -1);
            if (ec != Sqlite.OK) {
                warning ("%d: %s\n".printf (db.errcode (), db.errmsg ()));
                return matches;
            }

            // Use the prepared statement:
            while (stmt.step () == Sqlite.ROW) {

                Episode current_ep = episode_from_row (stmt);

                //Add the new episode
                matches.add (current_ep);

            }

            stmt.reset ();
            return matches;
        }


        /*
         * Removes a podcast from the library
         */
        public void remove_podcast (Podcast podcast) {

            string query, errmsg;
            int ec;

            // Delete the podcast's episodes from the database
            query = "DELETE FROM Episode WHERE podcast_uri = '%s';".printf (podcast.feed_uri.replace ("'", "%27"));


            ec = db.exec (query, null, out errmsg);
            if (ec != Sqlite.OK) {
                warning ("Error: %d: %s\n", db.errcode (), db.errmsg ());
                return;
            }

            // Delete the podcast from the database
            query = "DELETE FROM Podcast WHERE feed_uri = '%s';".printf (podcast.feed_uri);
            ec = db.exec (query, null, out errmsg);

            if (ec != Sqlite.OK) {
                warning ("Error: %d: %s\n", db.errcode (), db.errmsg ());
            }

            // Remove the local object as well
            podcasts.remove (podcast);
        }

        public Gee.ArrayList<Podcast>? search_by_term (string term) {

            prepare_database ();

            Sqlite.Statement stmt;

            var search_pods = new Gee.ArrayList<Podcast> ();

            string prepared_query_str = "SELECT * FROM Podcast WHERE name='%s' ORDER BY name".printf (term);
            int ec = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
            if (ec != Sqlite.OK) {
                warning ("%d: %s\n".printf (db.errcode (), db.errmsg ()));
                return null;
            }

            // Use the prepared statement:

            while (stmt.step () == Sqlite.ROW) {
                Podcast current = podcast_from_row (stmt);

                search_pods.add (current);
            }

            stmt.reset ();

            return search_pods;
        }

        public Episode episode_from_row (Statement stmt) {
            Episode episode = new Episode ();

            for (int i = 0; i < stmt.column_count (); i++) {
                string col_name = stmt.column_name (i) ?? "<none>";
                string val = stmt.column_text (i) ?? "<none>";

                if (col_name == "title") {
                    episode.title = val;
                }
                else if (col_name == "description") {
                    episode.description = val;
                }
                else if (col_name == "uri") {
                    episode.uri = val;
                }
                else if (col_name == "local_uri") {
                    if (val != " (null)")
                        episode.local_uri = val;
                } else if (col_name == "released") {
                    episode.datetime_released = new GLib.DateTime.from_unix_local (int64.parse(val));
                }
                else if (col_name == "download_status") {
                    if (val == "downloaded") {
                        episode.current_download_status = DownloadStatus.DOWNLOADED;
                    }
                    else {
                        episode.current_download_status = DownloadStatus.NOT_DOWNLOADED;
                    }
                }
                else if (col_name == "play_status") {
                    if (val == "played") {
                        episode.status = EpisodeStatus.PLAYED;
                    } else {
                        episode.status = EpisodeStatus.UNPLAYED;
                    }
                }
                else if (col_name == "latest_position") {
                    uint64 position = 0;
                    if (uint64.try_parse (val, out position)) {
                        episode.last_played_position = position;
                    }
                }
                else if (col_name == "parent_podcast_name") {
                    episode.parent = new Podcast.with_name (val);
                } else if (col_name == "podcast_uri") {
                    episode.podcast_uri = val;
                } else if (col_name == "guid") {
                    episode.guid = val;
                } else if (col_name == "link") {
                    episode.link = val;
                } else if (col_name == "duration") {
                    episode.duration = val;
                }
             }

            return episode;
        }

        public Podcast podcast_from_row (Statement stmt) {
            Podcast podcast = new Podcast ();

            for (int i = 0; i < stmt.column_count (); i++) {
                string col_name = stmt.column_name (i) ?? "<none>";
                string val = stmt.column_text (i) ?? "<none>";

                if (col_name == "name") {
                    podcast.name = val;
                }
                else if (col_name == "feed_uri") {
                    podcast.feed_uri = val;
                }
                else if (col_name == "album_art_url") {
                    podcast.remote_art_uri = val;
                }
                else if (col_name == "album_art_local_uri") {
                    //podcast.local_art_uri = val;
                }
                else if (col_name == "description") {
                    podcast.description = val;
                }
                else if (col_name == "content_type") {
                    if (val == "audio") {
                        podcast.content_type = MediaType.AUDIO;
                    }
                    else if (val == "video") {
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
        public void set_episode_playback_position (Episode episode) {
            write_episode_to_database (episode);
        }

        public void set_new_local_album_art (string path_to_local_file, Podcast p) {

            // Copy the file
            GLib.File current_file = GLib.File.new_for_path (path_to_local_file);

            //InputStream input_stream = current_file.read ();

            string path = local_library_path + "/%s/cover.jpg".printf (p.name.replace ("%27", "'").replace ("%", "_"));
            GLib.File local_file = GLib.File.new_for_path (path);


            current_file.copy_async.begin (local_file, FileCopyFlags.OVERWRITE, Priority.DEFAULT, null, null, (obj,res) => {
                try {
                    current_file.copy_async.end(res);
                } catch (Error e) {
                    warning (e.message);
                }
            });

            // Set the new file location in the database
            string query, errmsg;
            int ec;

            query = """UPDATE Podcast SET album_art_local_uri = '%s' WHERE name = '%s'""".printf (local_file.get_uri (),p.name);

            ec = db.exec (query, null, out errmsg);

            if (ec != Sqlite.OK) {
                stderr.printf ("Error: %s\n", errmsg);
            }

            // Set the new file location for the podcast object
            //p.local_art_uri = local_file.get_uri ();

        }

        /*
         * Creates Vocal's config directory, establishes a new SQLite database, and creates
         *  tables for both Podcasts and Episodes
         */
        public bool setup_library () {

            // Create the local library
            GLib.DirUtils.create_with_parents (local_library_path, 0775);

            // Create the vocal folder if it doesn't exist
            GLib.DirUtils.create_with_parents (db_directory, 0775);

            create_db_schema ();

            return true;

        }

        public void create_db_schema () {

            prepare_database ();

            string query = """
              BEGIN TRANSACTION;

              CREATE TABLE Podcast (
                name                TEXT                    NOT NULL,
                feed_uri            TEXT    PRIMARY KEY     NOT NULL,
                album_art_url       TEXT,
                album_art_local_uri TEXT,
                description         TEXT                    NOT NULL,
                content_type        TEXT,
                license             TEXT
              );

              CREATE INDEX podcast_name ON Podcast (name);

              CREATE TABLE Episode (
                title               TEXT                    NOT NULL,
                podcast_uri         TEXT                    NOT NULL,
                uri                 TEXT                    NOT NULL,
                local_uri           TEXT,
                released            INT,
                description         TEXT,
                latest_position     TEXT,
                download_status     TEXT,
                play_status         TEXT,
                guid                TEXT,
                link                TEXT,
                duration            TEXT
              );

              CREATE UNIQUE INDEX episode_guid ON Episode (guid, link, podcast_uri);
              CREATE INDEX episode_title ON Episode (title);
              CREATE INDEX episode_released ON Episode (released);

              PRAGMA user_version = 1;

              END TRANSACTION;
            """;

            int ec = db.exec (query, null);
            if (ec != Sqlite.OK) {
                error ("unable to create database schema %d: %s", db.errcode (), db.errmsg ());
            }

            return;
        }


        /*
         * INSERT/REPLACE a Podcast in the database
         */
        public bool write_podcast_to_database (Podcast podcast) {

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
             * but is left to remain consistent with existing db entries since the name
             * is currently used as the key field. */
            string name = podcast.name.replace ("'", "%27");

            stmt.bind_text (1, name);
            stmt.bind_text (2, podcast.feed_uri);
            stmt.bind_text (3, podcast.remote_art_uri);
            stmt.bind_text (4, "");
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
        public bool write_episode_to_database (Episode episode) {

            assert (episode.podcast_uri != null && episode.podcast_uri != "");

            string query = "INSERT OR REPLACE INTO Episode " +
                           " (title, podcast_uri, uri, local_uri, released, description, latest_position, download_status, play_status, guid, link, duration) " +
                           " VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12);";

            Sqlite.Statement stmt;
            int ec = db.prepare_v2 (query, query.length, out stmt);

            if (ec != Sqlite.OK) {
                warning ("Unable to prepare episode update statement. %d: %s", db.errcode (), db.errmsg ());
                return false;
            }

            /* This is here for compatibility. Escaping these values should not be necessary
             * but is done to remain consistent with existing db entries since the title
             * and podcast name are currently used as key fields. */
            string title = episode.title.replace ("'", "%27");

            // convert enums to text representations.
            string played_text = (episode.status == EpisodeStatus.PLAYED) ? "played" : "unplayed";
            string download_text = (episode.current_download_status == DownloadStatus.DOWNLOADED) ? "downloaded" : "not_downloaded";

            stmt.bind_text (1, title);
            stmt.bind_text (2, episode.podcast_uri);
            stmt.bind_text (3, episode.uri);
            stmt.bind_text (4, episode.local_uri);
            stmt.bind_int64 (5, episode.datetime_released.to_unix ());
            stmt.bind_text (6, episode.description);
            stmt.bind_text (7, episode.last_played_position.to_string ());
            stmt.bind_text (8, download_text);
            stmt.bind_text (9, played_text);
            stmt.bind_text (10, episode.guid);
            stmt.bind_text (11, episode.link);
            stmt.bind_text (12, episode.duration);

            ec = stmt.step ();

            if (ec != Sqlite.DONE) {
                warning ("Unable to insert/update episode. %d: %s", db.errcode (), db.errmsg ());
                return false;
            }

            return true;
        }


        /*
         * Returns the Sqlite user_version pragma used for checking current db schema version.
         * https://www.sqlite.org/pragma.html#pragma_user_version
         */
        private int get_db_version () {
            if (db == null) {
                prepare_database ();
            }

            int version = 0;
            int ec = db.exec ("PRAGMA user_version", (n_cols, values, col_names) => {
                    version = int.parse(values[0]);
                    return 0;
                }, null);

            if (ec != Sqlite.OK) {
                error ("Unable to determine database schema version! (%d) %s.",
                       db.errcode (), db.errmsg ());
            }

            return version;
        }

    }
}

