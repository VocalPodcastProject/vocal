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

  Additional contributors/authors:
  
  * Artem Anufrij <artem.anufrij@live.de>
  
***/


using Gtk;
using GLib;
using Granite;

namespace Vocal {

	public class CoverArt : Gtk.Box {

        private const int COVER_SIZE = 170;

		public Gtk.Image 	image;					// The actual coverart image
		private Gtk.Overlay count_overlay;			// Overlays the count on top of the banner
		private Gtk.Label 	count_label;			// The label that stores the unplayed count
		private Gtk.Label   podcast_name_label;     // The label that show the name of the podcast
		                                                // (if it is enabled in the settings)

		public Podcast podcast;						// Refers to the podcast this coverart represents


		/*
		 * Constructor for CoverArt given an image path and a podcast
		 */
		public CoverArt(string path, Podcast podcast, bool? show_mimetype = false) {
		
			this.podcast = podcast;
			this.margin = 10;
			this.orientation = Gtk.Orientation.VERTICAL;

			// Load the actual cover art
			var file = GLib.File.new_for_uri(path.replace("%27", "'"));

			var icon = new GLib.FileIcon(file);

			var image = new Gtk.Image.from_gicon(icon, Gtk.IconSize.DIALOG);
			image.pixel_size = COVER_SIZE;
			image.set_no_show_all(false);
			image.show();
			
			count_overlay = new Gtk.Overlay();

			// Partially set up the overlays
			count_overlay.add(image);
			
            
			if(count_overlay == null)
				count_overlay = new Gtk.Overlay();

			// Create a label to display the number of new episodes
			count_label = new Gtk.Label("");
			count_label.use_markup = true;
			count_label.set_alignment(1,0);
			count_label.get_style_context().add_class("coverart-overlay");
			count_label.halign = Gtk.Align.END;
			count_label.valign = Gtk.Align.START;
			count_label.width_chars = 2;
			count_label.xalign = 0.50f;
			count_label.margin_top = 3;
			count_label.margin_right = 3;

			// Add a tooltip
			this.tooltip_text = podcast.name.replace("%27", "'");

			// Set up the overlays

			count_overlay.add_overlay(count_label);
			
			this.pack_start(count_overlay, false, false, 0);

			this.valign = Align.START;
			string podcast_name = GLib.Uri.unescape_string(podcast.name);
			if (podcast_name == null) {
			    podcast_name = podcast.name.replace("%25", "%");
			}
			podcast_name = podcast_name.replace("&", """&amp;""");

			podcast_name_label = new Gtk.Label("<b>" + podcast_name + "</b>");
			podcast_name_label.wrap = true;
			podcast_name_label.use_markup = true;
			podcast_name_label.max_width_chars = 15;
			this.pack_start(podcast_name_label, false, false, 12);
			
			if(!VocalSettings.get_default_instance().show_name_label) {
			    podcast_name_label.no_show_all = true;
			    podcast_name_label.visible = false;
			}

			show_all();
		}

		/*
		 * Creates a pixbuf given an InputStream
		 */
        public static Gdk.Pixbuf create_cover_image (InputStream input_stream) throws Error {
            var cover_image = new Gdk.Pixbuf.from_stream (input_stream);

            if (cover_image.height == cover_image.width) {
                cover_image = cover_image.scale_simple (COVER_SIZE, COVER_SIZE, Gdk.InterpType.BILINEAR);
            }

            if (cover_image.height > cover_image.width) {

                int new_height = COVER_SIZE * cover_image.height / cover_image.width;
                int new_width = COVER_SIZE;
                int offset = (new_height - new_width) / 2;

                cover_image = new Gdk.Pixbuf.subpixbuf(cover_image.scale_simple (new_width, new_height, Gdk.InterpType.BILINEAR), 0, offset, COVER_SIZE, COVER_SIZE);

            } else if (cover_image.height < cover_image.width) {

                int new_height = COVER_SIZE;
                int new_width = COVER_SIZE * cover_image.width / cover_image.height;
                int offset = (new_width - new_height) / 2;

                cover_image = new Gdk.Pixbuf.subpixbuf(cover_image.scale_simple (new_width, new_height, Gdk.InterpType.BILINEAR), offset, 0, COVER_SIZE, COVER_SIZE);
            }

            return cover_image;
        }

		/*
		 * Hides the banner and the count
		 */
		public void hide_count()
		{
		    if (count_label != null) {
			    count_label.set_no_show_all(true);
			    count_label.hide();
		    }
		}
	
		/*
		 * Sets the banner count
		 */
		public void set_count(int count)
		{
		    if (count_label != null) {
			    count_label.set_text("%d".printf(count));
            }
		}
		
		/*
		 * Shows the banner and the count
		 */
		public void show_count()
		{
		    if (count_label != null) {
			    count_label.set_no_show_all(false);
			    count_label.show();
		    }
		}


		/*
		 * Shows the name label underneath the cover art
		 */
		public void show_name_label() {
		    if(podcast_name_label != null) {
			    podcast_name_label.no_show_all = false;
			    podcast_name_label.visible = true;
		    }
		}

		/*
		 * Hides the name label underneath the cover art
		 */
	 	public void hide_name_label() {
	 	    if(podcast_name_label != null) {
	     		podcast_name_label.no_show_all = true;
			    podcast_name_label.visible = false;
		    }
	 	}
	}
}
