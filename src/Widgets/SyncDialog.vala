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

using Gtk;

namespace Vocal {

    public class SyncDialog : Gtk.Dialog { 
    
        public signal void login_requested (string username, string password);     
        
        private Gtk.Box content_box;
        private Controller controller;
        
        private Gtk.Label gpodder_username_label;
        private Gtk.Entry gpodder_username_entry;
        
        private Gtk.Label gpodder_password_label;
        private Gtk.Entry gpodder_password_entry; 
        
        private Gtk.Button login_button;
        
        public SyncDialog (Controller controller) {
            
            title = _("Library Synchronization");
            this.controller = controller;
            
            (get_header_bar () as Gtk.HeaderBar).show_close_button = false;
            get_header_bar ().get_style_context ().remove_class ("header-bar");

            this.modal = true;
            this.resizable = false;
            this.set_transient_for(controller.window);
            content_box = get_content_area () as Gtk.Box;
            content_box.homogeneous = false;
            content_box.margin = 12;
            content_box.spacing = 6;
            
            var notebook = new Gtk.Stack ();
            notebook.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            notebook.transition_duration = 300;
            
            var login_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var device_name_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var overview_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            
            notebook.add_named (login_box, "login");
            notebook.add_named (device_name_box, "devices");
            notebook.add_named (overview_box, "overview");
            
            content_box.pack_start (notebook, true, true, 0);
            
            
            // Login Box

            var title_label = new Gtk.Label (_("Sign in to gpodder.net"));
            title_label.get_style_context ().add_class ("h1");
            login_box.pack_start (title_label, true, true, 12);
            
            var username_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            gpodder_username_label = new Gtk.Label (_("Username"));
            gpodder_username_entry = new Gtk.Entry ();
            
            username_box.pack_start (gpodder_username_label, true, true, 12);
            username_box.pack_start (gpodder_username_entry, true, true, 12);
            
            var password_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            gpodder_password_label = new Gtk.Label (_("Password"));
            gpodder_password_entry = new Gtk.Entry ();
            gpodder_password_entry.visibility = false;
            gpodder_password_entry.activate.connect ( () => {
                if (gpodder_password_entry.text.length > 1) {
                    login_requested (gpodder_username_entry.text, gpodder_password_entry.text);
                }
            });
            
            password_box.pack_start (gpodder_password_label, true, true, 12);
            password_box.pack_start (gpodder_password_entry, true, true, 12);
            
            login_box.pack_start (username_box, false, false, 12);
            login_box.pack_start (password_box, false, false, 12);
            
            login_button = new Gtk.Button.with_label (_("Login"));
            login_box.pack_start (login_button, true, true, 12);
            
            login_button.clicked.connect ( () => {
                notebook.set_visible_child (device_name_box);
                //login_requested (gpodder_username_entry.text, gpodder_password_entry.text);
            });
            
            var account_linkbutton = new Gtk.LinkButton.with_label ("https://gpodder.net/register/", _("Need an account?"));
            account_linkbutton.xalign = 0.0f;
            
            login_box.pack_start (account_linkbutton, true, true, 0);
            
            
            // Device Box
            
            var device_title = new Gtk.Label (_("Pick a New Device Name for This Computer"));
            device_title.get_style_context ().add_class ("h1");
            
            device_name_box.pack_start (device_title, true, true, 12);
            
            var device_name_entry = new Gtk.Entry ();
            device_name_entry.text = controller.settings.gpodder_device_name;
            
            var known_device_expander = new Gtk.Expander (_("Or, Choose an Existing Device"));
            var known_device_dropdown = new Gtk.ComboBox ();
            var complete_setup_button = new Gtk.Button.with_label (_("Complete Setup"));
            
            complete_setup_button.clicked.connect ( () => {
                notebook.set_visible_child (overview_box);
            });
            
            known_device_expander.add (known_device_dropdown);
            
            device_name_box.pack_start (device_title, true, true, 12);
            device_name_box.pack_start (device_name_entry, true, true, 12);
            device_name_box.pack_start (known_device_expander, true, true, 12);
            device_name_box.pack_start (complete_setup_button, true, true, 12);
            
            notebook.set_visible_child (login_box);
            
            // Overview Box
            
            var last_sync_label = new Gtk.Label (_("Latest Successful Sync: Never"));
            var logout_button = new Gtk.Button.with_label (_("Logout"));            
            var full_sync_button = new Gtk.Button.with_label (_("Perform a Full Sync Now"));
            
            var episode_sync_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            var sync_episodes_label = new Gtk.Label (_("Sync Episode Activity"));
            var sync_episodes_switch = new Gtk.Switch ();
            
            sync_episodes_switch.active = controller.settings.gpodder_sync_episode_status;
            sync_episodes_switch.activate.connect ( () => {
                controller.settings.gpodder_sync_episode_status = sync_episodes_switch.active;
            });
            
            episode_sync_box.pack_start (sync_episodes_label, true, true, 12);
            episode_sync_box.pack_start (sync_episodes_switch, true, true, 12);
            
            overview_box.pack_start (last_sync_label, true, true, 12);
            overview_box.pack_start (logout_button, true, true, 12);
            overview_box.pack_start (full_sync_button, true, true, 12);
            overview_box.pack_start (episode_sync_box, true, true, 12);
            
            
            this.set_size_request (50, 50);
        }
        
    }
}
