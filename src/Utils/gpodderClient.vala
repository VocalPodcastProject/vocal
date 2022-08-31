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

	public enum EpisodeAction {
		DOWNLOAD, PLAY, DELETE, NEW;
	}

    public class gpodderClient {

        private static gpodderClient _default_instance = null;

        private Vocal.Application controller;

        public static gpodderClient get_default_instance(Vocal.Application controller) {
            if(_default_instance == null)
                _default_instance = new gpodderClient (controller);

            return _default_instance;
        }

        private gpodderClient (Vocal.Application controller) {

            this.controller = controller;
        }

        public bool login (string username, string password) {

            string endpoint = "https://gpodder.net/api/2/auth/%s/login.json".printf (username);
            var message = new Soup.Message ("POST", endpoint);

            var session = new Soup.Session ();
            session.user_agent = "vocal";

            int counter = 0;
            message.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        auth.authenticate (username, password);
			        counter++;
		        }
		        return retrying;
	        });

            try {
                session.send (message);

                if (message.status_code == 200) {
                    controller.password_manager.store_password_async.begin ("gpodder.net-password", password, (obj, res) => {
                        try {
                            controller.password_manager.store_password_async.end(res);
                        } catch (Error e) {
                            warning (e.message);
                        }
                    });
                    controller.settings.gpodder_username = username;
                    return true;
                }
            } catch (Error e) {
                warning(e.message);
            }

            return false;
        }

        public bool update_device_data () {
	        string endpoint = "https://gpodder.net/api/2/devices/%s/%s.json".printf (controller.settings.gpodder_username, controller.settings.gpodder_device_name);
            var message = new Soup.Message ("PUT", endpoint);

            var session = new Soup.Session ();
            session.user_agent = "vocal";

            int counter = 0;
            message.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }

                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        try {
                            string? password = controller.password_manager.get_password_async.end(res);
	                        if (password != null){
	                            auth.authenticate (controller.settings.gpodder_username, password);
                            }
		                    counter++;
	                    } catch (Error e) {
	                        warning (e.message);
	                    }
                    });

		        }
		        return retrying;
	        });


            string jsonbody =
            """
            {
            	"caption": "Vocal running on my computer",
                "type": "laptop"
            }
            """;

            var bytes = new GLib.Bytes(jsonbody.data);
            message.set_request_body_from_bytes ("text/json", bytes);

            try {
                session.send (message);

                if (message.status_code == 200) {
                    return true;
                }
            } catch (Error e) {
                warning (e.message);
            }

            return false;
        }

        public bool upload_subscriptions () {

            string endpoint = "https://gpodder.net/subscriptions/%s/%s.txt".printf (controller.settings.gpodder_username, controller.settings.gpodder_device_name);
            var message = new Soup.Message ("PUT", endpoint);

            string subs = "";
            foreach (Podcast p in controller.library.podcasts) {
                subs += p.feed_uri + "\n";
            }

            var session = new Soup.Session ();
            session.user_agent = "vocal";

            int counter = 0;
            message.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        try {
                            string? password = controller.password_manager.get_password_async.end(res);
		                    if (password != null){
		                        auth.authenticate (controller.settings.gpodder_username, password);
	                        }
		                    counter++;
	                    } catch (Error e) {
	                        warning (e.message);
	                    }
                    });
		        }
		        return retrying;
	        });



            var bytes = new GLib.Bytes(subs.data);
            message.set_request_body_from_bytes ("text/plain", bytes);

            try {
                session.send (message);

                if (message.status_code == 200) {
                    return true;
                } else {
                    return false;
                }
            } catch (Error e) {
                warning (e.message);
            }

            return false;
        }

        public async bool upload_subscriptions_async () {

            SourceFunc callback = upload_subscriptions_async.callback;
            bool result = false;

            ThreadFunc<bool> run = () => {
                string endpoint = "https://gpodder.net/subscriptions/%s/%s.txt".printf (controller.settings.gpodder_username, controller.settings.gpodder_device_name);
                var message = new Soup.Message ("PUT", endpoint);

                string subs = "";
                foreach (Podcast p in controller.library.podcasts) {
                    subs += p.feed_uri + "\n";
                }

                var session = new Soup.Session ();
                session.user_agent = "vocal";

                int counter = 0;
                message.authenticate.connect ((msg, auth, retrying) => {
		            if (counter < 3) {
			            if (retrying == true) {
				            warning ("Invalid user name or password.\n");
			            }
                        controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                            try {
                                string? password = controller.password_manager.get_password_async.end(res);
		                        if (password != null){
		                            auth.authenticate (controller.settings.gpodder_username, password);
	                            }
		                        counter++;
	                        } catch (Error e) {
	                            warning (e.message);
	                        }
                        });
		            }
		            return retrying;
	            });


                var bytes = new GLib.Bytes(subs.data);
                message.set_request_body_from_bytes ("text/plain", bytes);

                try {
                    session.send (message);

                    if (message.status_code == 200) {
                        result = true;
                    }
                } catch (Error e) {
                    warning (e.message);
                }

                Idle.add((owned) callback);
                return true;
            };

            new Thread<bool>("update-subscriptions-async", run);

            yield;

            return result;
        }

        public GLib.List<string> get_device_list () {
            string endpoint = "https://gpodder.net/api/2/devices/%s.json".printf (controller.settings.gpodder_username);
            var message = new Soup.Message ("GET", endpoint);
            List<string> list = new List<string> ();

            var session = new Soup.Session ();
            session.user_agent = "vocal";

            int counter = 0;
            message.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        try {
                            string? password = controller.password_manager.get_password_async.end(res);
		                    if (password != null){
		                        auth.authenticate (controller.settings.gpodder_username, password);
	                        }
		                    counter++;
	                    } catch (Error e) {
	                        warning (e.message);
	                    }
                    });
		        }
		        return retrying;
	        });

            try {
                var response = session.send (message);
                DataInputStream dis = new DataInputStream (@response);
                size_t len;
		        string str = dis.read_upto ("\0", 1, out len);

                //TODO: parse message response and append items to the list
                var parser = new Json.Parser ();
			    parser.load_from_data (str, -1);

			    Json.Array? root_array = parser.get_root ().get_array ();
			    if (root_array != null) {
				    for (int i = 0; i < root_array.get_length (); i++) {
					    var object_element = root_array.get_object_element (i);
					    var device_name = object_element.get_string_member ("id");
					    info (device_name);
					    list.append (device_name);
				    }
			    }
		    } catch (Error e) {
		        warning (e.message);
		    }

            return list;
        }

        public string get_subscriptions_list () {

            string result = "";

            string endpoint = "https://gpodder.net/subscriptions/%s.opml".printf (controller.settings.gpodder_username);
            var message = new Soup.Message ("GET", endpoint);

            var session = new Soup.Session ();
            session.user_agent = "vocal";

            int counter = 0;
            message.authenticate.connect ((msg, auth, retrying) => {
	            if (counter < 3) {
		            if (retrying == true) {
			            warning ("Invalid user name or password.\n");
		            }
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        try {
                            string? password = controller.password_manager.get_password_async.end(res);
	                        if (password != null){
	                            auth.authenticate (controller.settings.gpodder_username, password);
                            }
	                        counter++;
                        } catch (Error e) {
                            warning (e.message);
                        }
                    });
	            }
	            return retrying;
            });

            try {
                var response = session.send (message);
                DataInputStream dis = new DataInputStream (@response);
                size_t len;
	            result = dis.read_upto ("\0", 1, out len);
            } catch (Error e) {
                warning (e.message);
            }

            return result;
        }


        public async string get_subscriptions_list_async () {

            SourceFunc callback = get_subscriptions_list_async.callback;
            string result = "";

            ThreadFunc<bool> run = () => {

                string endpoint = "https://gpodder.net/subscriptions/%s.opml".printf (controller.settings.gpodder_username);
                var message = new Soup.Message ("GET", endpoint);

                var session = new Soup.Session ();
                session.user_agent = "vocal";

                int counter = 0;
                message.authenticate.connect ((msg, auth, retrying) => {
		            if (counter < 3) {
			            if (retrying == true) {
				            warning ("Invalid user name or password.\n");
			            }
                        controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                            try {
                                string? password = controller.password_manager.get_password_async.end(res);
		                        if (password != null){
		                            auth.authenticate (controller.settings.gpodder_username, password);
	                            }
		                        counter++;
	                        } catch (Error e) {
	                            warning (e.message);
	                        }
                        });
		            }
		            return retrying;
	            });

                try {
                    var response = session.send (message);
                    DataInputStream dis = new DataInputStream (@response);
                    size_t len;
		            result = dis.read_upto ("\0", 1, out len);
	            } catch (Error e) {
	                warning (e.message);
	            }
	            Idle.add((owned) callback);
                return true;
            };
		    new Thread<bool>("get-subscriptions-list-async", run);
            yield;
            return result;
        }

        public bool get_episode_updates () {
            string endpoint = "https://gpodder.net/api/2/episodes/%s.json".printf (controller.settings.gpodder_username);
	        if(controller.settings.gpodder_last_successful_sync_timestamp != "") {
	        	endpoint += "?since=%s&aggregated=true".printf (controller.settings.gpodder_last_successful_sync_timestamp);
	        } else {
	        	endpoint += "?aggregated=true";
	        }

	        var message = new Soup.Message ("GET", endpoint);

        	var session = new Soup.Session ();
            session.user_agent = "vocal";

            int counter = 0;
            message.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        try {
                            string? password = controller.password_manager.get_password_async.end(res);
		                    if (password != null){
		                        auth.authenticate (controller.settings.gpodder_username, password);
	                        }
		                    counter++;
	                    } catch (Error e) {
	                        warning (e.message);
	                    }
                    });
		        }
		        return retrying;
	        });


            string str = "";

            try {
                var response = session.send (message);
                DataInputStream dis = new DataInputStream (@response);
                size_t len;
		        str = dis.read_upto ("\0", 1, out len);
	        } catch (Error e) {
	            warning (e.message);
	        }

            if (message.status_code == 200) {

            	info ("Episode actions successfully loaded. Parsing results and updating records.");

            	var parser = new Json.Parser ();
            	try {
				    parser.load_from_data (str, -1);
			    } catch (Error e) {
			        warning (e.message);
			    }

				var root_object = parser.get_root ().get_object ();
				var actions = root_object.get_array_member ("actions");

            	// If we've never synced actions before, all we care about is the current timestamp
            	if(controller.settings.gpodder_last_successful_sync_timestamp != "") {

					foreach (var action in actions.get_elements ()) {
						var object = action.get_object ();
						var podcast = object.get_string_member ("podcast");
						var episode = object.get_string_member ("episode");
						var action_type = object.get_string_member ("action");
						int64 position = 0;
						if (action_type == "play") {

							// The only interesting action to update is a 'play' event, to get the new position
							// We don't really care if other devices deleted or downloaded an episode file

							position = object.get_int_member ("position");

							// Locate the episode in the library and update it
							foreach (var lib_podcast in controller.library.podcasts) {
								if (lib_podcast.feed_uri == podcast) {
									foreach (var lib_episode in lib_podcast.episodes ) {
										if (lib_episode.uri == episode) {
											lib_episode.last_played_position = (int)position;
											controller.library.set_episode_playback_position (lib_episode);
											break;
										}
									}
								}
							}
						}
					}
				}

				var updated_timestamp = root_object.get_int_member ("timestamp");
				controller.settings.gpodder_last_successful_sync_timestamp = updated_timestamp.to_string ();

                return true;
            } else {
                return false;
            }
        }

        public async bool get_episode_updates_async () {

            SourceFunc callback = get_episode_updates_async.callback;
            bool result = false;

            ThreadFunc<bool> run = () => {
                string endpoint = "https://gpodder.net/api/2/episodes/%s.json".printf (controller.settings.gpodder_username);
	            if(controller.settings.gpodder_last_successful_sync_timestamp != "") {
	            	endpoint += "?since=%s&aggregated=true".printf (controller.settings.gpodder_last_successful_sync_timestamp);
	            } else {
	            	endpoint += "?aggregated=true";
	            }

	            var message = new Soup.Message ("GET", endpoint);

            	var session = new Soup.Session ();
                session.user_agent = "vocal";

                int counter = 0;
                message.authenticate.connect ((msg, auth, retrying) => {
		            if (counter < 3) {
			            if (retrying == true) {
				            warning ("Invalid user name or password.\n");
			            }
                        controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                            try{
                                string? password = controller.password_manager.get_password_async.end(res);
		                        if (password != null){
		                            auth.authenticate (controller.settings.gpodder_username, password);
	                            }
		                        counter++;
	                        } catch (Error e) {
	                            warning (e.message);
	                        }
                        });
		            }
		            return retrying;
	            });

	            string str = "";

                try {
                    var response = session.send (message);
                    DataInputStream dis = new DataInputStream (@response);
                    size_t len;
		            str = dis.read_upto ("\0", 1, out len);
		        } catch (Error e) {
		            warning (e.message);
		        }


                if (message.status_code == 200) {

                	info ("Episode actions successfully loaded. Parsing results and updating records.");

                	var parser = new Json.Parser ();

                	try {
				        parser.load_from_data (str, -1);

				        var root_object = parser.get_root ().get_object ();
				        var actions = root_object.get_array_member ("actions");

                    	// If we've never synced actions before, all we care about is the current timestamp
                    	if(controller.settings.gpodder_last_successful_sync_timestamp != "") {

					        foreach (var action in actions.get_elements ()) {
						        var object = action.get_object ();
						        var podcast = object.get_string_member ("podcast");
						        var episode = object.get_string_member ("episode");
						        var action_type = object.get_string_member ("action");
						        int64 position = 0;
						        if (action_type == "play") {

							        // The only interesting action to update is a 'play' event, to get the new position
							        // We don't really care if other devices deleted or downloaded an episode file

							        position = object.get_int_member ("position");

							        // Locate the episode in the library and update it
							        foreach (var lib_podcast in controller.library.podcasts) {
								        if (lib_podcast.feed_uri == podcast) {
									        foreach (var lib_episode in lib_podcast.episodes ) {
										        if (lib_episode.uri == episode) {
											        info("Updated episode playback position: %s,%d".printf (lib_episode.title, (int) position));
											        lib_episode.last_played_position = (int) position;
											        controller.library.set_episode_playback_position (lib_episode);
											        break;
										        }
									        }
								        }
							        }
						        }
					        }
				        }

				        var updated_timestamp = root_object.get_int_member ("timestamp");
				        controller.settings.gpodder_last_successful_sync_timestamp = updated_timestamp.to_string ();
				        result = true;
			        } catch (Error e) {
			            warning (e.message);
			        }
                }
                Idle.add((owned) callback);
                return true;
            };
            new Thread<bool>("get-episode-updates-async", run);
            yield;
            return result;
        }

        public bool update_episode (Episode episode, EpisodeAction action) {
            string endpoint = "https://gpodder.net/api/2/episodes/%s.json".printf (controller.settings.gpodder_username);
            var message = new Soup.Message ("POST", endpoint);

            var session = new Soup.Session ();
            session.user_agent = "vocal";

            int counter = 0;
            message.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }

                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        try {
                            string? password = controller.password_manager.get_password_async.end(res);
		                    if (password != null){
		                        auth.authenticate (controller.settings.gpodder_username, password);
	                        }
		                    counter++;
		                } catch (Error e) {
		                    warning (e.message);
		                }

                    });

		        }
		        return retrying;
	        });

        	string timestamp = new GLib.DateTime.now_utc ().to_string ();

        	info(episode.last_played_position.to_string());

			string jsonbody;
			if (action == EpisodeAction.DOWNLOAD || action == EpisodeAction.DELETE || action == EpisodeAction.NEW) {
				jsonbody = """
				{
					"podcast": "%s",
					"episode": "%s",
					"device": "%s",
					"action": "%s",
					"timestamp": "%s"
				}
				""".printf(episode.parent.feed_uri, episode.uri, controller.settings.gpodder_device_name, action.to_string ().down (), timestamp);
			} else {
				jsonbody =
				"""
				[
					{
						"podcast": "%s",
						"episode": "%s",
						"device": "%s",
						"action": "play",
						"position": %s,
						"timestamp": "%s"
					}
				]
				""".printf(episode.parent.feed_uri, episode.uri, controller.settings.gpodder_device_name, ((int)episode.last_played_position).to_string (), timestamp);
			}


            var bytes = new GLib.Bytes(jsonbody.data);
            message.set_request_body_from_bytes ("text/json", bytes);

            try {
                session.send (message);

                if (message.status_code == 200) {
                	info ("Episode progress updated in gpodder.net for " + episode.title);
                    return true;
                } else {
                	info ("Failed to update progress in gpodder.net for " + episode.title);
                    return false;
                }
            } catch (Error e) {
                warning (e.message);
            }

            return false;
        }

        public async void update_all_episode_positions_async () {
            SourceFunc callback = update_all_episode_positions_async.callback;
            ThreadFunc<bool> run = () => {
            	foreach (Podcast p in controller.library.podcasts) {
            		foreach (Episode e in p.episodes) {
            			update_episode (e, EpisodeAction.PLAY);
            		}
            	}
            	Idle.add((owned) callback);
                return true;
        	};

        	new Thread<bool>("update-all-episode-positions-async", run);
        	yield;
        }
    }
}
