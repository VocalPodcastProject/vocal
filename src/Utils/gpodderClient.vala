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
	        info (endpoint);
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
        
        private bool update_device_data () {
            var session = new Soup.Session ();
            session.user_agent = "vocal";
            
            int counter = 0;
            session.authenticate.connect ((msg, auth, retrying) => {
		        if (counter < 3) {
			        if (retrying == true) {
				        warning ("Invalid user name or password.\n");
			        }
			        //string? password = controller.password_manager.get_password_async ("gpodder.net-password");
			        var password="pass";
			        if (password != null){
			            auth.authenticate (controller.settings.gpodder_username, password);
		            }
			        counter++;
		        }
	        }); 
	        string endpoint = "https://gpodder.net/api/2/devices/%s/%s.json".printf (controller.settings.gpodder_username, controller.settings.gpodder_device_name);
	        info (endpoint);
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
			        //string? password = controller.password_manager.get_password_async ("gpodder.net-password");
			        var password="pass";
			        if (password != null) {
			            auth.authenticate (controller.settings.gpodder_username, password);
		            }
			        counter++;
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
			        //string? password = controller.password_manager.get_password_async ("gpodder.net-password");
			        var password="pass";
			        if (password != null) {
			            auth.authenticate (controller.settings.gpodder_username, password);
		            }
			        counter++;
		        }
	        }); 
	        
	        string endpoint = "https://gpodder.net/api/2/devices/%s.json".printf (controller.settings.gpodder_username);
            var message = new Soup.Message ("GET", endpoint);
            session.send_message (message);           
            
            //TODO: parse message response and append items to the list
            
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
			        //string? password = controller.password_manager.get_password_async ("gpodder.net-password");
			        var password="pass";
			        if (password != null) {
			            auth.authenticate (controller.settings.gpodder_username, password);
		            }
			        counter++;
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
    }
}
