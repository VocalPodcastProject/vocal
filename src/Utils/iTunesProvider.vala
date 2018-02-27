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

namespace Vocal {

    public class iTunesProvider {

        private SoupClient soup_client = null;

        public iTunesProvider() {
            soup_client = new SoupClient();
        }

        /*
         * Finds the public RSS feed address from any given iTunes store URL
         */
        public string? get_rss_from_itunes_url(string itunes_url, out string? name = null) {

            string rss = "";

            // We just need to get the iTunes store iD
            int start_index = itunes_url.index_of("/id") + 3;
            int stop_index = itunes_url.index_of("?");

            string id = itunes_url.slice(start_index, stop_index);

            var uri =  "https://itunes.apple.com/lookup?id=%s&entity=podcast".printf(id);

            try {
                var parser = new Json.Parser ();
                parser.load_from_stream (soup_client.request(HttpMethod.GET, uri));

                var root_object = parser.get_root ().get_object ();

                if(root_object == null) {
                    stdout.puts("Error. Root object was null.");
                    return null;
                }

                var elements = root_object.get_array_member("results").get_elements();

                foreach(Json.Node e in elements) {
                    var obj = e.get_object();
                    rss = obj.get_string_member("feedUrl");
                    name = obj.get_string_member("trackName");
                }
            } catch (Error e) {
                warning ("An error occurred while discovering the real RSS feed address %s\n", e.message);
            }

            return rss;
        }

        /*
         * Finds the top n podcasts (100 by default) and returns it in an ArrayList
         */
        public GLib.List<DirectoryEntry>? get_top_podcasts(int? limit = 100) {
        

            var settings = VocalSettings.get_default_instance();

            var uri =  "https://itunes.apple.com/%s/rss/toppodcasts/limit=%d/json".printf(settings.itunes_store_country, limit);

            GLib.List<DirectoryEntry> entries = new GLib.List<DirectoryEntry>();

            var parser = new Json.Parser ();

            try {
                parser.load_from_data ((string) soup_client.send_message(HttpMethod.GET, uri), -1);
            } catch (Error e) {
                warning ("An error occured fetching the top podcasts. %s", e.message);
                return null;
            }

            var root_object = parser.get_root ().get_object ();
            if(root_object == null) {
                error ("Error loading iTunes results. Root object was null.");
                return null;
            }

            var elements = root_object.get_object_member("feed").get_array_member ("entry").get_elements();
            

            foreach(Json.Node e in elements) {

                // Create a new DirectoryEntry to store the results
                DirectoryEntry ent = new DirectoryEntry();

                var obj = e.get_object();
                if (obj != null) {

                    // Objects
                    var id = obj.get_object_member("id"); // The podcast store URL
                    if (id != null)
                        ent.itunesUrl = id.get_string_member("label");
                    var title = obj.get_object_member("title");
                    if (title != null)
                        ent.title = title.get_string_member("label");
                    var summary = obj.get_object_member("summary");
                    if (summary != null)
                        ent.summary = summary.get_string_member("label");
                    var artist = obj.get_object_member("im:artist");
                    if (artist != null) 
                        ent.artist = artist.get_string_member("label");

                    // Remove the artist name from the title
                    ent.title = ent.title.replace(" - " + ent.artist, "");

                    // Arrays
                    var image = obj.get_member("im:image").get_array().get_elements();

                    int i = 0;

                    foreach(Json.Node f in image) {
                        switch(i) {
                            case 0:
                                ent.artworkUrl55 = f.get_object().get_string_member("label");
                                break;
                            case 1:
                                ent.artworkUrl60 = f.get_object().get_string_member("label");
                                break;
                            case 2:
                                ent.artworkUrl170 = f.get_object().get_string_member("label");
                                break;
                        }
                        i++;
                    }

                    entries.append(ent);
                }

            }
            

            return entries;
        }

        /*
         * Finds the top n podcasts that match a given term in the iTunes store and returns
         * them in an ArrayList
         */
        public Gee.ArrayList<DirectoryEntry>? search_by_term(string term, int? limit = 25) {

            var uri = "https://itunes.apple.com/search?term=%s&entity=podcast&limit=%d".printf(term.replace(" ", "+"), limit);

            Gee.ArrayList<DirectoryEntry> entries = new Gee.ArrayList<DirectoryEntry>();

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) soup_client.send_message(HttpMethod.GET, uri), -1);

                var root_object = parser.get_root ().get_object ();

                if(root_object == null) {
                    stdout.puts("Error. Root object was null.");
                    return null;
                }


                var elements = root_object.get_array_member ("results").get_elements();

                foreach(Json.Node e in elements) {


                    // Create a new DirectoryEntry to store the results
                    DirectoryEntry ent = new DirectoryEntry();

                    // Objects
                    ent.itunesUrl = e.get_object().get_string_member("collectionViewUrl");
                    ent.title = e.get_object().get_string_member("collectionName");
                    ent.artist = e.get_object().get_string_member("artistName");

                    // Remove the artist name from the title
                    ent.title = ent.title.replace(" - " + ent.artist, "");

                    ent.artworkUrl600 = e.get_object().get_string_member("artworkUrl600");

                    entries.add(ent);

                }

            } catch (Error e) {
                warning ("An error occurred while loading the iTunes results. %s", e.message);
            }

            return entries;
        }
    }
}
