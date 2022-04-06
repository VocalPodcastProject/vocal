/***
  BEGIN LICENSE

  Copyright (C) 2014-2019 Nathan Dyer <nathandyer@fastmail.com>
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

	public enum EpisodeAction {
		DOWNLOAD, PLAY, DELETE, NEW;
	}

    public class gpodderClient {
    
        private static gpodderClient _default_instance = null;

        private Controller controller;
        
        public static gpodderClient get_default_instance(Controller controller) {
            if(_default_instance == null)
                _default_instance = new gpodderClient (controller);

            return _default_instance;
        }
    
        private gpodderClient (Controller controller) {
            
            this.controller = controller;
        }
        
        public bool login (string username, string password) {
            
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        auth.authenticate (username, password);
			        counter++;
		        }
	        }); 
	        string endpoint = "https://gpodder.net/api/2/auth/%s/login.json".printf (username);
            var message = new Soup.Message ("POST", endpoint);
                
            session.send_message (message);

            if (message.status_code == 200) {
                controller.password_manager.store_password_async ("gpodder.net-password", password);
                controller.settings.gpodder_username = username;
                return true;
            } else {
                return false;
            }
        }
        
        public bool update_device_data () {
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
	        }); 
	        string endpoint = "https://gpodder.net/api/2/devices/%s/%s.json".printf (controller.settings.gpodder_username, controller.settings.gpodder_device_name);

            var message = new Soup.Message ("PUT", endpoint);
            
            string jsonbody = 
            """
            {
            	"caption": "Vocal running on my computer",
                "type": "laptop"
            }
            """;
            
            message.set_request ("text/json", Soup.MemoryUse.STATIC, jsonbody.data);
            session.send_message (message);
            
            if (message.status_code == 200) {
                return true;
            } else {
                return false;
            }
        }
        
        public bool upload_subscriptions () {
        
            string subs = "";
            foreach (Podcast p in controller.library.podcasts) {
                subs += p.feed_uri + "\n";
            }
            
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
	        }); 
	        
	        string endpoint = "https://gpodder.net/subscriptions/%s/%s.txt".printf (controller.settings.gpodder_username, controller.settings.gpodder_device_name);
            var message = new Soup.Message ("PUT", endpoint);
            
            message.set_request ("text/plain", Soup.MemoryUse.STATIC, subs.data);
            session.send_message (message);

            if (message.status_code == 200) {
                return true;
            } else {
                return false;
            }
        }
        
        public async bool upload_subscriptions_async () {
        
            string subs = "";
            foreach (Podcast p in controller.library.podcasts) {
                subs += p.feed_uri + "\n";
            }
            
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
	        }); 
	        
	        string endpoint = "https://gpodder.net/subscriptions/%s/%s.txt".printf (controller.settings.gpodder_username, controller.settings.gpodder_device_name);
            var message = new Soup.Message ("PUT", endpoint);
            
            message.set_request ("text/plain", Soup.MemoryUse.STATIC, subs.data);
            session.send_message (message);

            if (message.status_code == 200) {
                return true;
            } else {
                return false;
            }
        }
        
        public GLib.List<string> get_device_list () {
            List<string> list = new List<string> ();
            
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
	        }); 
	        
	        string endpoint = "https://gpodder.net/api/2/devices/%s.json".printf (controller.settings.gpodder_username);
            var message = new Soup.Message ("GET", endpoint);
            session.send_message (message);           
            
            //TODO: parse message response and append items to the list
            var parser = new Json.Parser ();
			parser.load_from_data ((string) message.response_body.flatten ().data, -1);

			Json.Array? root_array = parser.get_root ().get_array ();
			if (root_array != null) {
				for (int i = 0; i < root_array.get_length (); i++) {
					var object_element = root_array.get_object_element (i);
					var device_name = object_element.get_string_member ("id");
					info (device_name);
					list.append (device_name);
				}
			}
			
            return list;
        }
        
        public string get_subscriptions_list () {
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
	        }); 
	        
	        string endpoint = "https://gpodder.net/subscriptions/%s.opml".printf (controller.settings.gpodder_username);
            var message = new Soup.Message ("GET", endpoint);
            session.send_message (message);
            
            if (message.status_code == 200) {
                return (string)message.response_body.data;
            } else {
                return "";
            }
        }
        
        
        public async string get_subscriptions_list_async () {
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
	        }); 
	        
	        string endpoint = "https://gpodder.net/subscriptions/%s.opml".printf (controller.settings.gpodder_username);
            var message = new Soup.Message ("GET", endpoint);
            session.send_message (message);
            
            if (message.status_code == 200) {
                return (string)message.response_body.data;
            } else {
                return "";
            }
        }
        
        public bool get_episode_updates () {
        
        	var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
	        }); 
	        string endpoint = "https://gpodder.net/api/2/episodes/%s.json".printf (controller.settings.gpodder_username);
	        if(controller.settings.gpodder_last_successful_sync_timestamp != "") {
	        	endpoint += "?since=%s&aggregated=true".printf (controller.settings.gpodder_last_successful_sync_timestamp);
	        } else {
	        	endpoint += "?aggregated=true";
	        }
	        
	        var message = new Soup.Message ("GET", endpoint);
            session.send_message (message);
            
            if (message.status_code == 200) {
            	
            	info ("Episode actions successfully loaded. Parsing results and updating records.");
            	
            	var parser = new Json.Parser ();
				parser.load_from_data ((string) message.response_body.flatten ().data, -1);

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
        
        	var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
	        }); 
	        string endpoint = "https://gpodder.net/api/2/episodes/%s.json".printf (controller.settings.gpodder_username);
	        if(controller.settings.gpodder_last_successful_sync_timestamp != "") {
	        	endpoint += "?since=%s&aggregated=true".printf (controller.settings.gpodder_last_successful_sync_timestamp);
	        } else {
	        	endpoint += "?aggregated=true";
	        }
	        
	        var message = new Soup.Message ("GET", endpoint);
            session.send_message (message);
            
            if (message.status_code == 200) {
            	
            	info ("Episode actions successfully loaded. Parsing results and updating records.");
            	
            	var parser = new Json.Parser ();
				parser.load_from_data ((string) message.response_body.flatten ().data, -1);

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
				
                return true;
            } else {
                return false;
            }
        }
        
        public bool update_episode (Episode episode, EpisodeAction action) {

			if (controller.settings.gpodder_username == "") {
				return false;
			}
        
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        var loop = new MainLoop();
                    controller.password_manager.get_password_async.begin("gpodder.net-password", (obj, res) => {
                        string? password = controller.password_manager.get_password_async.end(res);
		                if (password != null){
		                    auth.authenticate (controller.settings.gpodder_username, password);
	                    }
		                counter++;
                        loop.quit();
                    });
                    loop.run();
		        }
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
			
	        string endpoint = "https://gpodder.net/api/2/episodes/%s.json".printf (controller.settings.gpodder_username);
            var message = new Soup.Message ("POST", endpoint);
            
            message.set_request ("text/json", Soup.MemoryUse.STATIC, jsonbody.data);
            session.send_message (message);
            
            info ((string)message.response_body.data);
            info (message.status_code.to_string ());

            if (message.status_code == 200) {
            	info ("Episode progress updated in gpodder.net for " + episode.title);
                return true;
            } else {
            	info ("Failed to update progress in gpodder.net for " + episode.title);
                return false;
            }
        }
        
        public async void update_all_episode_positions_async () {
        	foreach (Podcast p in controller.library.podcasts) {
        		foreach (Episode e in p.episodes) {
        			update_episode (e, EpisodeAction.PLAY);
        		}
        	}
        }
    }
}
