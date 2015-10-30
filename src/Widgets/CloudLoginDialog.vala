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

using Gtk;

namespace Vocal {

    
    public class CloudLoginDialog : Gtk.Dialog {

        public signal void input_ready();
    
        private	Gtk.Entry 	uname_entry;			
        private Gtk.Entry 	pw_entry;

        string password;
        string username;


    
        public CloudLoginDialog(Window parent) {
            set_default_response(Gtk.ResponseType.OK);
            set_size_request(500, 200);
            set_modal(true);
            set_transient_for(parent);
            set_attached_to(parent);
            set_resizable(false);
            setup();
            get_action_area().margin = 7;
            this.title = _("Login to gPodder.net");
        }
            
        /*
         * Sets up the properties of the dialog
         */
        private void setup() {

            uname_entry = new Gtk.Entry();
            uname_entry.placeholder_text = _("Username");
            pw_entry = new Gtk.Entry();
            pw_entry.placeholder_text = _("Password");
            unichar ast = '*';
            pw_entry.invisible_char = ast;
            pw_entry.visibility = false;

            var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
            content_box.margin_right = 12;
            content_box.margin_left = 12;

            content_box.pack_start(uname_entry, false, false, 5);
            content_box.pack_start(pw_entry, false, false, 5);

            var hor_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 15);

            var login_button = new Gtk.Button.with_label(_("Login"));
            var register_button = new Gtk.Button.with_label(_("Register for gPodder.net"));

            register_button.xalign = 0;

            login_button.get_style_context().add_class("suggested-action");

            login_button.clicked.connect(() => {
                input_ready();
            });

            register_button.clicked.connect(() => {

                try {
                  GLib.Process.spawn_command_line_async ("xdg-open http://gpodder.net/register");
                } catch (Error e) {}
                
            }); 


            hor_box.pack_start(register_button, false, false, 5);
            hor_box.pack_start(login_button, true, true, 5);
            content_box.pack_start(hor_box, false, false, 5);

            this.get_content_area().add(content_box);
        }
    }
}