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

using Gtk;

namespace Vocal {

    public class SyncDialog : Gtk.Dialog {

        public signal void login_requested (string username, string password);

        private Gtk.Box content_box;
        private Application controller;

        private Gtk.Label gpodder_username_label;
        private Gtk.Entry gpodder_username_entry;

        private Gtk.Label gpodder_password_label;
        private Gtk.Entry gpodder_password_entry;

        private Gtk.Button login_button;

        private Gtk.Stack notebook;
        private Gtk.Box login_box;
        private Gtk.Box device_name_box;
        private Gtk.Box overview_box;

        private Gtk.ComboBox known_device_dropdown;
        private GLib.List<string> device_list;

        public SyncDialog (Application controller, Gtk.Widget parent) {

            title = _("Library Synchronization");
            this.controller = controller;

            this.modal = true;
            this.resizable = false;
            //this.set_parent(parent);
            content_box = get_content_area () as Gtk.Box;
            content_box.homogeneous = false;
            Utils.set_margins(content_box, 12);
            content_box.spacing = 6;

            this.set_size_request (50, 50);

            notebook = new Gtk.Stack ();
            notebook.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            notebook.transition_duration = 300;

            login_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            device_name_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            overview_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

            notebook.add_named (login_box, "login");
            notebook.add_named (device_name_box, "devices");
            notebook.add_named (overview_box, "overview");

            content_box.append (notebook);

            this.show.connect ( () => {
            	if (controller.settings.gpodder_username != "") {
		        	notebook.set_visible_child (overview_box);
		        }
            });

            // Login Box

            var title_label = new Gtk.Label (_("Sign in to gpodder.net"));
            title_label.get_style_context ().add_class ("title-3");
            login_box.append (title_label);

            var username_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            gpodder_username_label = new Gtk.Label (_("Username"));
            gpodder_username_entry = new Gtk.Entry ();
            gpodder_username_label.hexpand = true;

            username_box.append (gpodder_username_label);
            username_box.append (gpodder_username_entry);

            var password_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            gpodder_password_label = new Gtk.Label (_("Password"));
            gpodder_password_entry = new Gtk.Entry ();
            gpodder_password_entry.visibility = false;
            gpodder_password_entry.activate.connect ( () => {
                on_login_request ();
            });

            gpodder_password_label.hexpand = true;

            password_box.append (gpodder_password_label);
            password_box.append (gpodder_password_entry);

            login_box.append (username_box);
            login_box.append (password_box);

            login_button = new Gtk.Button.with_label (_("Login"));
            login_box.append (login_button);

            login_button.clicked.connect ( () => {
                on_login_request ();
            });

            var account_linkbutton = new Gtk.LinkButton.with_label ("https://gpodder.net/register/", _("Need an account?"));

            login_box.append (account_linkbutton);


            // Device Box

            var device_title = new Gtk.Label (_("Pick a New Device Name for This Computer"));
            device_title.get_style_context ().add_class ("h1");

            device_name_box.append (device_title);

            var device_name_entry = new Gtk.Entry ();
            device_name_entry.text = controller.settings.gpodder_device_name;

            var known_device_expander = new Gtk.Expander (_("Or, Choose an Existing Device"));
            known_device_dropdown = new Gtk.ComboBox ();
            Gtk.CellRendererText renderer = new Gtk.CellRendererText ();
            known_device_dropdown.pack_start (renderer, true);
            known_device_dropdown.add_attribute (renderer, "text", 0);

            var complete_setup_button = new Gtk.Button.with_label (_("Complete Setup"));

            complete_setup_button.clicked.connect ( () => {
                if (controller.gpodder_client.update_device_data ()) {
		            notebook.set_visible_child (overview_box);
		            controller.gpodder_client.upload_subscriptions ();
		            string cloud_subs_opml = controller.gpodder_client.get_subscriptions_list ();
		            controller.library.add_from_OPML.begin (cloud_subs_opml, false, false, (obj, res) => {
		                controller.library.add_from_OPML.end(res);
		            });
                }
            });

            known_device_expander.set_child (known_device_dropdown);

            known_device_expander.activate.connect ( () => {
                if (known_device_expander.expanded) {
                    device_name_entry.sensitive = true;
                } else {
                    device_name_entry.sensitive = false;
                }
            });

            // Update device name
            known_device_dropdown.changed.connect ( () => {
            	if (device_name_entry.sensitive == false) {
            		int active_id = known_device_dropdown.active;
            		controller.settings.gpodder_device_name = device_list.nth_data (active_id);
            	}
            });

            device_name_entry.changed.connect ( () => {
            	if (device_name_entry.sensitive == true) {
            		controller.settings.gpodder_device_name = device_name_entry.text;
            	}
            });

            device_name_box.append (device_title);
            device_name_box.append (device_name_entry);
            device_name_box.append (known_device_expander);
            device_name_box.append (complete_setup_button);

            // Overview Box

            var last_sync_label = new Gtk.Label (_("Latest Successful Sync: Never"));
            var logout_button = new Gtk.Button.with_label (_("Logout"));
            var full_sync_button = new Gtk.Button.with_label (_("Perform a Full Sync Now"));

            full_sync_button.clicked.connect (on_full_sync_clicked);

            if (controller.settings.gpodder_last_successful_sync_timestamp != "") {
		        int64 last_sync_timestap = int64.parse(controller.settings.gpodder_last_successful_sync_timestamp);
		        var last_sync_datetime = new DateTime.from_unix_utc (last_sync_timestap);
		        last_sync_label.label = _("Last Successful Sync: " + last_sync_datetime.to_local ().to_string ());
	        }

            logout_button.clicked.connect (() => {
            	controller.settings.gpodder_username = "";
            	notebook.set_visible_child (login_box);
            });

            var episode_sync_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            episode_sync_box.halign = Gtk.Align.END;
            episode_sync_box.valign = Gtk.Align.CENTER;
            var sync_episodes_label = new Gtk.Label (_("Sync Episode Activity"));
            var sync_episodes_switch = new Gtk.Switch ();

            sync_episodes_switch.active = controller.settings.gpodder_sync_episode_status;
            sync_episodes_switch.activate.connect ( () => {
                controller.settings.gpodder_sync_episode_status = sync_episodes_switch.active;
            });

            episode_sync_box.append (sync_episodes_label);
            episode_sync_box.append (sync_episodes_switch);

            var remove_podcast_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            remove_podcast_box.halign = Gtk.Align.END;
            remove_podcast_box.valign = Gtk.Align.CENTER;
            var remove_podcast_label = new Gtk.Label (_("Remove Podcasts from Library That Have Been Removed From Your gpodder.net Account"));
            remove_podcast_label.wrap = true;
            remove_podcast_label.max_width_chars = 30;
            remove_podcast_label.justify = Gtk.Justification.RIGHT;
            var remove_podcast_switch = new Gtk. Switch ();
            remove_podcast_switch.valign = Gtk.Align.CENTER;

            remove_podcast_switch.active = controller.settings.gpodder_remove_deleted_podcasts;
            remove_podcast_switch.activate.connect ( () => {
            	controller.settings.gpodder_remove_deleted_podcasts = remove_podcast_switch.active;
            });

            remove_podcast_box.append (remove_podcast_label);
            remove_podcast_box.append (remove_podcast_switch);

            overview_box.append (last_sync_label);
            overview_box.append (logout_button);
            overview_box.append (full_sync_button);
            overview_box.append (episode_sync_box);
            overview_box.append (remove_podcast_box);

        }

        private void on_login_request () {
            if (gpodder_username_entry.text.length > 1 && gpodder_password_entry.text.length > 1) {
                var successful_login = controller.gpodder_client.login (gpodder_username_entry.text, gpodder_password_entry.text);

                if (successful_login) {
                    // Load list of devices
                    Gtk.ListStore list_store = new Gtk.ListStore (1, typeof(string));
                    Gtk.TreeIter iter;

                    device_list = controller.gpodder_client.get_device_list ();

                    foreach(string s in device_list) {
                        list_store.append (out iter);
                        list_store.set (iter, 0, s);
                    }

                    known_device_dropdown.set_model (list_store);
                    known_device_dropdown.active = 0;

                    // Show device picker
                    notebook.set_visible_child (device_name_box);
                } else {
                    gpodder_password_entry.text = "";
                    gpodder_password_entry.grab_focus ();
                }
            }
        }

        private void on_full_sync_clicked () {
        	//controller.window.show_infobar (_("Checking for new podcast subscriptions from your other devices…"), MessageType.INFO);
        	var loop = new MainLoop();
        	controller.gpodder_client.get_subscriptions_list_async.begin ((obj, res) => {

                string cloud_subs_opml = controller.gpodder_client.get_subscriptions_list_async.end (res);
    			controller.library.add_from_OPML.begin (cloud_subs_opml, true, false, (obj,res) => {
    			    controller.library.add_from_OPML.end(res);
    			});

                // Next, get any episode updates
                //controller.window.show_infobar (_("Updating episode playback positions from your other devices…"), MessageType.INFO);
                controller.gpodder_client.get_episode_updates_async.begin ((obj, res) => {

                	controller.gpodder_client.get_episode_updates_async.end (res);

                	// If necessary, remove podcasts from library that are missing in
                	if (controller.settings.gpodder_remove_deleted_podcasts) {

                		//controller.window.show_infobar (_("Cleaning up old subscriptions no longer in your gpodder.net account…"), MessageType.INFO);

                		// TODO: use a singleton pattern so there's only one instance
                		FeedParser feed_parser = new FeedParser ();
                		try {
                    		string[] cloud_feeds = feed_parser.parse_feeds_from_OPML (cloud_subs_opml, true);
                    		foreach (Podcast p in controller.library.podcasts) {
                    			bool found = false;
                    			foreach (string feed in cloud_feeds) {
                    				if (p.feed_uri == feed) {
                    					found = true;
                					}
                    			}
                    			if (!found) {
                    				// Remove podcast
                    				controller.library.remove_podcast (p);
                    			}
                    		}
                		} catch (Error e) {
                		    warning (e.message);
                		}
                	}

                	// Update all the episode statuses
                	//controller.window.show_infobar (_("Uploading all episode positions to gpodder.net…"), MessageType.INFO);
                	controller.gpodder_client.update_all_episode_positions_async.begin ((obj, res) => {
                		controller.gpodder_client.update_all_episode_positions_async.end (res);
                		//controller.window.hide_infobar ();
                		loop.quit ();
                	});
                });
            });
            loop.run ();
        }
    }
}
