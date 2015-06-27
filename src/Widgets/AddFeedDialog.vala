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

    
    public class AddFeedDialog : Gtk.Dialog {
    
        public	Gtk.Entry 	entry;			
        private Gtk.Button 	cancel_button;
        public	Gtk.Button 	add_feed_button;

	private bool		on_elementary;
    
        public AddFeedDialog(Window parent, bool? using_elementary = true) {
	    this.on_elementary = using_elementary;
            set_default_response(Gtk.ResponseType.OK);
            set_size_request(500, 150);
            set_modal(true);
            set_transient_for(parent);
            set_attached_to(parent);
            set_resizable(false);
            setup();
            get_action_area().margin = 7;
            this.title = _("Add New Podcast");
        }
            
        /*
         * Sets up the properties of the dialog
         */
        private void setup() {
            var content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            content_box.margin_right = 12;
            content_box.margin_left = 12;
            
            var add_label = new Gtk.Label(_("<b>Add a new podcast feed to the library</b>"));
            add_label.use_markup = true;
            add_label.xalign = 0;
            
            entry = new Gtk.Entry();
            entry.placeholder_text = _("Podcast feed web address");
            entry.activates_default = false;
            entry.margin = 12;
            entry.changed.connect(on_entry_changed);
            
            cancel_button = new Gtk.Button.with_label(_("Cancel"));
            cancel_button.clicked.connect(() => {
                this.destroy();
            });
            
            Gtk.Image add_img;
	    if(on_elementary)
	        add_img = new Gtk.Image.from_icon_name ("add", Gtk.IconSize.DIALOG);
	    else
		add_img = new Gtk.Image.from_icon_name ("list-add", Gtk.IconSize.DIALOG);
            add_img.margin_right = 12;
            
            content_box.add(add_img);
            content_box.add(add_label);
            
            // Add items to box
            add_button ("_Cancel", Gtk.ResponseType.CANCEL);
            add_feed_button = (Gtk.Button)add_button("_Add Podcast", Gtk.ResponseType.OK);
            add_feed_button.get_style_context().add_class("suggested-action");
            add_feed_button.sensitive = false;
            
            // Set up the text entry activate signal to "click" the add button
            entry.activate.connect(() => {
                if(add_feed_button.sensitive)
                    add_feed_button.clicked();
            });
            
            
            this.get_content_area().add(content_box);
            this.get_content_area().add(entry);

        }  
        
        /*
         * Set the button's sensitivity based on whether or not there is any input
         */
        private void on_entry_changed()
        {
            if(entry.text.length > 0) {
                add_feed_button.sensitive = true;
            } else {
                add_feed_button.sensitive = false;
            }
        }
    }
}
