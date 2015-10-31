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
  	public class SecretEntryPopover : Gtk.Popover {

        public signal void code_accepted(string code_id);

        // Darn you cheating scoundrels for taking the easy way out. I'm onto you :)
        private string[] codes = { "camelot", "roundel" };
        
        private Gtk.Entry entry;

        public SecretEntryPopover(Gtk.Widget parent) {
            this.set_relative_to(parent);

            entry = new Gtk.Entry();
            entry.activate.connect(on_entry_activate);
            entry.margin = 12;

            this.add(entry);
            this.get_style_context().add_class("secret-entry");
        }

        private void on_entry_activate() {
            switch(entry.text) {
                case "camelot":
                    code_accepted("camelot");
                    break;
                case "roundel":
                    code_accepted("roundel");
                    break;
                default:
                    break;
            }

            entry.text = "";
        }
    }
}