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
            
            title = _("gpodder.net Synchronization");
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
            
            var username_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            gpodder_username_label = new Gtk.Label (_("Username"));
            gpodder_username_entry = new Gtk.Entry ();
            
            username_box.pack_start (gpodder_username_label, true, true, 12);
            username_box.pack_start (gpodder_username_entry, true, true, 12);
            
            var password_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            gpodder_password_label = new Gtk.Label (_("Password"));
            gpodder_password_entry = new Gtk.Entry ();
            
            password_box.pack_start (gpodder_password_label, true, true, 12);
            password_box.pack_start (gpodder_password_entry, true, true, 12);
            
            content_box.pack_start (username_box, false, false, 12);
            content_box.pack_start (password_box, false, false, 12);
            
            login_button = new Gtk.Button.with_label (_("Login"));
            login_button.clicked.connect ( () => {
                //TODO: fix saving logic. This is just a POC
                controller.password_manager.store_password_async ("gpodder.net-password", gpodder_password_entry.text);
                login_requested (gpodder_username_entry.text, gpodder_password_entry.text);
            });
            content_box.pack_start (login_button, true, true, 12);
            this.set_size_request (50, 50);
        }
    }
}
