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

using Gee;
using GLib;
using Gdk;
using Gtk;
using Granite;

namespace Vocal {
    public class DownloadsPopover : Gtk.Popover {


        public signal void 	all_downloads_complete();		// signal that gets fired when all downloads are finished
    
        private Gtk.ListBox listbox;						// displays the download details boxes
        private Gtk.Label 	downloads_complete;				// a label that gets shown when all downloads are finished
        
        public ArrayList<DownloadDetailBox> downloads;		// stores the download detail boxes
        
        /*
         * Constructor for a downloads popover that is relative to a provided parent
         */
        public DownloadsPopover(Gtk.Widget parent) {
            this.set_relative_to(parent);
            this.listbox = new Gtk.ListBox();
            listbox.selection_mode = SelectionMode.NONE;
            
            downloads = new ArrayList<DownloadDetailBox>();
            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scroll.min_content_height = 200;

            downloads_complete = new Gtk.Label(_("No active downloads."));
            Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H3, downloads_complete);
            listbox.prepend(downloads_complete);

            this.add(scroll);
            scroll.add(listbox);
        }
        
        /*
         * Adds a download to the popover
         */
        public void add_download(DownloadDetailBox details) {

            if(downloads.size < 1) {
                hide_downloads_complete();
            }           
            
            details.ready_for_removal.connect(remove_details_box);
            details.cancel_requested.connect(() => {
                remove_details_box(details);
            });
            
            // If there are multiple downloads, add a separator
            if(downloads.size >= 1)  {
		          details.show_separator();
            }

            
            // Add the new download to the queue and listbox
            downloads.add(details);
            
            listbox.prepend(details);
            listbox.show_all();
        }
        
        
        /*
		 * Hides the downloads complete label
		 */
        private void hide_downloads_complete() {
            downloads_complete.set_no_show_all(true);
            downloads_complete.hide();
            downloads_complete.show_all();
        }
        
        
        /*
         * Removes a download from the popover
         */
        private void remove_details_box(DownloadDetailBox box) {
            downloads.remove(box);
            this.remove(box);
            box.destroy();
            
            if(downloads.size < 1) {
                show_downloads_complete();

                // If the popover is not currently showing, send a signal to hide the menuitem
                if(this.visible != true)
                  all_downloads_complete();
            }
        }
        

		/*
		 * Shows the downloads complete label
		 */
        private void show_downloads_complete() {
            downloads_complete.set_no_show_all(false);
            downloads_complete.show_all();
        }
    }
}
