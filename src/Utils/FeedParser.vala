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

using Xml;
using Gee;
using GLib;
using Vocal;

namespace Vocal {

    errordomain VocalUpdateError {
        NETWORK_ERROR;
    }
    
    class FeedParser {

        private Gee.ArrayList<string> queue = new Gee.ArrayList<string>();


        /*
         * Creates a new podcast by iterating through the queue and finding appropriate
         * key/value pairs
         */
        private Podcast create_podcast_from_queue() {
        
            // Create the new podcast object
            Podcast podcast = new Podcast();
            
            bool found_podcast_title = false;
            bool found_podcast_link = false;
            bool found_cover_art = false;
            bool found_main_description = false;
            
            int i = 0;
            
            while (i < queue.size) {
                string current = queue[i];
                
                // Title can be ambigous, so only accept the first one
                if (current == "title" && found_podcast_title == false) {
                    i++;
                    podcast.name = queue[i];
                    found_podcast_title = true;
                    i++;
                }
                else if (current == "new-feed-url"&& found_podcast_link == false) {
                    
                    i++;
                    podcast.feed_uri = queue[i];
                    found_podcast_link = true;
                    i++;
                }
                
                // Most feeds use the new-feed-url enclosure, but if not we have to check links manually
                else if (current == "link" && found_podcast_link == false) {
                    i++;
                    string href = null;
                    bool store_ref = false;
                    
                    // There are six fields, but we can't assume any order
                    for (int n = 0; n < 6; n++) {
                        if(queue[i+n] == "application/rss+xml") {
                            store_ref = true;
                        }
                        if(queue[i+n] == "href") {
                            href = queue[i + n + 1];
                        }
                    }
                    
                    if(store_ref) {
                        podcast.feed_uri = href;
                        found_podcast_link = true;
                    }
                    
                    
                }
                
                else if (current == "description" && found_main_description == false) {
                    i++;
                    podcast.description = queue[i];
                    found_main_description = true;
                    i++;
                }
                else if (current == "image" && found_cover_art == false) {
                
                    if(queue[i + 2] == "href") {
                        i += 3;
                        podcast.remote_art_uri = queue[i];
                    }
                    else {
                        while(queue[i] != "url") {
                            i++;
                        }
                        
                        i++;
                        podcast.remote_art_uri = queue[i];
                    }

                    found_cover_art = true;
                    i++;
                }
                
                // We've found an episode!!
                else if (current == "item") {
                    //stdout.puts("Episode found!\n");
                    
                    // Create a new episode
                    Episode episode = new Episode();
                    string next_item_in_queue = null;
                    bool found_summary = false;
                    
                    while (next_item_in_queue != "item" && i < queue.size - 1) {
                        i++;
                        next_item_in_queue = queue[i];
                        if(next_item_in_queue == "title") {
                            i++;
                            episode.title = queue[i];
                        }
                        else if(next_item_in_queue == "enclosure") {
                            bool uri_found = false;
                            bool type_found = false;
                            
                            // Because different podcasts enclose information differently,
                            // we must individually search for both the uri and the type
                            while(uri_found != true || type_found != true) {
                                // Look at next item
                                i++;
                                
                                if(queue[i] == "url") {
                                    
                                    i++;
                                    episode.uri = queue[i];
                                    uri_found = true;
                                    
                                }
                                else if(queue[i] == "type") {
                                    i++;

						            string typestring = queue[i].slice(0, 5);
						            if(podcast.content_type == MediaType.UNKNOWN) {
							            if(typestring == "audio") {
								            podcast.content_type = MediaType.AUDIO;
							            }
							            else if (typestring == "video") {
								            podcast.content_type = MediaType.VIDEO;
							            }
							            else {
							                podcast.content_type = MediaType.UNKNOWN;
							            }
							
						            }
						            
						            type_found = true;
					            }
					        }
                            
                        }
                        else if(next_item_in_queue == "pubDate") {
                            i++;
                            
                            episode.date_released = queue[i];
                            episode.set_datetime_from_pubdate();

                        }
                        else if(next_item_in_queue == "summary") {
                            i++;
                            episode.description = queue[i];
                            found_summary = true;
                        }
                        else if(next_item_in_queue == "description" && !found_summary) {
                            i++;
                            episode.description = queue[i];
                        }
                    }
                    
                    
                    // Add the new episode to the podcast
                    podcast.add_episode(episode);
                    
                }
                
                // Otherwise, simply increment and keep going
                else {
                    i++;
                }
            }
            
            return podcast;
        }
        
        
        
        /*
         * Parses a given XML file and returns a new podcast object if able to parse it properly
         */
        public Podcast? get_podcast_from_file(string path) throws GLib.Error {
        
            /*
                For reference: podcast rss feeds typically have the structure:
                0. Rss
                    1. Channel
                        2. Title 
                        2. Link
                        2. General
                            3. Explicit
                            3. Image URL
                            3. Etc..
                        2. ID1 (Episode)
                        2. ID2 (Episode)
                        2. ...
            */
        
            // Call the Xml.Parser to parse the file, which returns an unowned reference
            Xml.Doc* doc = Parser.parse_file (path);
            
            // Make sure that it didn't return a null reference
            if (doc == null) {
                warning ("Error opening file %s", path);
                return null;
            }

            // Get the root node
            Xml.Node* root = doc->get_root_element ();
            
            // Make sure that it didn't return a null reference, either
            if (root == null) {
            
                // If it did, free the document manually (since unowned)
                delete doc;
                warning ("The XML file '%s' is empty", path);
                return null;
            }
            
            // Parse the root node, which in turn will cause all nodes and properties to be parsed
            parse_node(root);
            
            // Create the podcast object and set it as parent to child episodes
            Podcast podcast = create_podcast_from_queue();
            foreach(Episode child in podcast.episodes) {
                child.parent = podcast;
                
            }
            
            if(podcast.coverart_uri == null) {
                podcast.coverart_uri = """//usr/share/vocal/vocal-missing.png""";
            }
            
            if(podcast.feed_uri == null) {
                podcast.feed_uri = path;
            }
            
            // Free the document
            delete doc;
            
            return podcast;
        }
        
         /*
         * Parses an OPML file and returns an array listing each feed discovered within
         */
        public string[] parse_feeds_from_OPML(string path) throws VocalLibraryError{
            ArrayList<string> feeds = new ArrayList<string>();
            
            queue.clear();

        
            // Call the Xml.Parser to parse the file, which returns an unowned reference
            Xml.Doc* doc = Parser.parse_file (path);
            
            // Make sure that it didn't return a null reference
            if (doc == null) {
                throw new VocalLibraryError.IMPORT_ERROR(_("Selected file doesn't appear to contain podcast subscriptions."));
            }

            // Get the root node
            Xml.Node* root = doc->get_root_element ();
            
            // Make sure that it didn't return a null reference, either
            if (root == null) {
            
                // If it did, free the document manually (since unowned)
                delete doc;
                warning(_("Selected file seems to be empty."));
                return feeds.to_array();
            }
           
            // Parse the root node, which in turn will cause all nodes and properties to be parsed
            parse_node(root);
            
            int i = 0;
            string current;
            
            while(i < queue.size - 1) {
                i++;
                current = queue[i];
                if (current == "url" || current == "xmlUrl") {
                    i++;
                    feeds.add(queue[i]);
                }
            }
            
            string[] feeds_array = feeds.to_array();
            return feeds_array;
        }

        /*
         * Parse the feed starting at a node (recursively called)
         */
        private void parse_node (Xml.Node* node) {
        
            // Loop over the passed node's children
            
            for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
            
                // Spaces between tags are also nodes, discard them
                if (iter->type != ElementType.ELEMENT_NODE) {
                    continue;
                }

                // Get the node's name
                string node_name = iter->name;
                queue.add(node_name);
                
                // Get the node's content with <tags> stripped
                string node_content = iter->get_content ();
                queue.add(node_content);
                
                // Now parse the node's properties (attributes) ...
                parse_properties (iter);

                // Followed by its children nodes
                parse_node (iter);
            }
        }

        /*
         * Parse the properties of a node
         */
        private void parse_properties (Xml.Node* node) {
        
            // Loop over the passed node's properties (attributes)
            for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
            
                string attr_name = prop->name;
                queue.add(attr_name);

                string attr_content = prop->children->content;
                queue.add(attr_content);

            }
        }

        /*
         * Re-parses the feed for a given podcast and finds episodes newer than the previous newest episode
         */
        public int update_feed(Podcast podcast) throws VocalUpdateError{
        
            Gee.ArrayList<Episode> new_episodes = new Gee.ArrayList<Episode>();
            bool previous_found = false;
            
            queue.clear();
            Episode previous_newest_episode = null;

            if(podcast.episodes.size > 0) {      
                previous_newest_episode = podcast.episodes[podcast.episodes.size - 1];
            }
            
            string path = podcast.feed_uri;

        
            // Call the Xml.Parser to parse the file, which returns an unowned reference
            Xml.Doc* doc = Parser.parse_file (path);
            
            // Make sure that it didn't return a null reference
            if (doc == null) {
                throw new VocalUpdateError.NETWORK_ERROR("Error opening file %s".printf(path));
            }

            // Get the root node
            Xml.Node* root = doc->get_root_element ();
            
            // Make sure that it didn't return a null reference, either
            if (root == null) {
            
                // If it did, free the document manually (since unowned)
                delete doc;
                throw new VocalUpdateError.NETWORK_ERROR("The XML file '%s' is empty".printf(path));
            }
            
            // Parse the root node, which in turn will cause all nodes and properties to be parsed
            parse_node(root);
            
            int i = 0;
            
            while ( i < queue.size && !previous_found) {
            
                if (queue[i] == "item") {
                    //stdout.puts("Episode found!\n");
                    
                    // Create a new episode
                    Episode episode = new Episode();
                    string next_item_in_queue = null;
                    bool found_summary = false;

                                        
                    while (next_item_in_queue != "item" && i < queue.size - 1) {
                        i++;
                        next_item_in_queue = queue[i];
                        if(next_item_in_queue == "title") {
                            i++;
                            episode.title = queue[i];
                        }
                        else if(next_item_in_queue == "enclosure") {
                            bool uri_found = false;
                            bool type_found = false;
                            
                            // Because different podcasts enclose information differently,
                            // we must individually search for both the uri and the type
                            while(uri_found != true || type_found != true) {
                                // Look at next item
                                i++;
                                
                                if(queue[i] == "url") {
                                    
                                    i++;
                                    episode.uri = queue[i];
                                    uri_found = true;
                                    
                                }
                                else if(queue[i] == "type") {
                                    i++;

					                string typestring = queue[i].slice(0, 5);
					                if(podcast.content_type == MediaType.UNKNOWN) {
						                if(typestring == "audio") {
							                podcast.content_type = MediaType.AUDIO;
						                }
						                else if (typestring == "video") {
							                podcast.content_type = MediaType.VIDEO;
						                }
						                else {
						                    podcast.content_type = MediaType.UNKNOWN;
						                }
						
					                }
					                
					                type_found = true;
				                }
				            }
                            
                        }
                        else if(next_item_in_queue == "pubDate") {
                            i++;
                            
                            episode.date_released = queue[i];
                            episode.set_datetime_from_pubdate();

                        }
                        else if(next_item_in_queue == "summary") {
                            i++;
                            episode.description = queue[i];
                            found_summary = true;
                        }
                        else if(next_item_in_queue == "description" && !found_summary) {
                            i++;
                            episode.description = queue[i];
                        }
                    }
                    
                    episode.parent = podcast;
                    
                    if(previous_newest_episode != null) {
                        if(episode.title == previous_newest_episode.title.replace("%27", "'")) {
                            previous_found = true;
                        } else {
                            new_episodes.add(episode);
                        }
                    } else {
                        new_episodes.add(episode);
                    }
                }
                
                // Otherwise, simply increment and keep going
                else {
                    i++;
                }
            }

            // Iterate through the arraylist of new episodes

            // Keep in mind that the newest episode is on the bottom, so go in reverse order
            for(int index = new_episodes.size - 1; index >= 0; index--) {
                podcast.episodes.add(new_episodes[index]);
            }

            int episodes_added = new_episodes.size;
            new_episodes = null;

            // Free up the space from the root node
            delete root;
            
            return episodes_added;

        }
    }
}
