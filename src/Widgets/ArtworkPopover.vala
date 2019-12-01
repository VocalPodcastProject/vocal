/***
  BEGIN LICENSE

  Copyright (C) 2014-2019 Nathan Dyer <mail@nathandyer.me>
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
    public class ArtworkPopover : Gtk.Popover {

        private Gtk.Label show_notes;
        private Gtk.Stack stack;
        private Gtk.StackSwitcher stack_switcher;
        public QueueBox queue_box;

        /*
         * Constructor for the shownotes popover relative to a given parent
         */
        public ArtworkPopover (Gtk.Widget parent) {
            this.set_relative_to (parent);
            
            // The artwork popover has two main widgets in a stack:
            // 		the shownotes and the queue
            
            var shownotes_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            queue_box = new QueueBox ();
            
            stack = new Gtk.Stack ();
            stack.add_titled (shownotes_box, "shownotes", _("Shownotes"));
            stack.add_titled (queue_box, "queue", _("Queue"));
            
            stack_switcher = new Gtk.StackSwitcher ();
            stack_switcher.set_stack (stack);

            // Set up the scrolled window
			var scrolled = new Gtk.ScrolledWindow (null, null);
			show_notes = new Gtk.Label ("");
			show_notes.label = "";
			show_notes.wrap = true;
			show_notes.wrap_mode = Pango.WrapMode.WORD;
			show_notes.use_markup = true;
			show_notes.margin = 10;
			scrolled.set_size_request (400, 200);
			scrolled.add (show_notes);
			shownotes_box.add (scrolled);
			
			var main_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			main_container.add (stack_switcher);
			main_container.add (stack);
			
			stack_switcher.halign = Gtk.Align.CENTER;
			stack_switcher.margin = 12;
			
			this.add (main_container);
        }

        /*
         * Sets the text in the popover
         */
        public void set_notes_text (string text) {
            this.show_notes.label = Utils.html_to_markup (text);
        }
      }
}
