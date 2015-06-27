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
	public class ShowNotesPopover : Gtk.Popover {

		private Gtk.TextView show_notes;

		/*
		 * Constructor for the shownotes popover relative to a given parent
		 */
		public ShowNotesPopover(Gtk.Widget parent) {
			this.set_relative_to(parent);

			// Set up the scrolled window
		  	var scrolled = new Gtk.ScrolledWindow(null, null);
		  	show_notes = new Gtk.TextView();
		  	show_notes.set_wrap_mode(Gtk.WrapMode.WORD);
		  	show_notes.buffer.text = "";
		  	show_notes.cursor_visible = false;
		  	show_notes.editable = false;
		  	show_notes.margin = 10;
		  	scrolled.set_size_request(400, 200);
		  	scrolled.add(show_notes);
		  	this.add(scrolled);
		}
	
		/*
		 * Sets the text in the popover
		 */
		public void set_notes_text(string text) {
			this.show_notes.buffer.text = Utils.html_to_markup(text);
		}
  	}
}
