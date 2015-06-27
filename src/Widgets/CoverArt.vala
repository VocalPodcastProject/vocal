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

        private const int COVER_SIZE = 150;

		private Gtk.Image 	image;					// The actual coverart image
		private Gtk.Image 	triangle;				// The banner in the top right corner
		private Gtk.Overlay triangle_overlay;		// Overlays the banner on top of the image
		private Gtk.Overlay count_overlay;			// Overlays the count on top of the banner
		private Gtk.Label 	count_label;			// The label that stores the unplayed count

		public Podcast podcast;						// Refers to the podcast this coverart represents


		/*
		 * Constructor for CoverArt given an image path and a podcast
		 */
		public CoverArt(string path, Podcast podcast, bool? show_mimetype = false) {

			this.podcast = podcast;
			this.margin = 10;

			try {

				// Load the actual cover art
				File cover_file = GLib.File.new_for_uri(path.replace("%27", "'"));
				bool exists = cover_file.query_exists();
				if(!exists)
				{
					info("Coverart at %s doesn't exist.".printf(path.replace("%27", "'")));
				}
	            InputStream input_stream = cover_file.read();
	            var coverart_pixbuf = create_cover_image (input_stream);

	            image = new Gtk.Image.from_pixbuf(coverart_pixbuf);

	            // Load the banner to be drawn on top of the cover art
				File triangle_file = GLib.File.new_for_uri("""file:///usr/share/vocal/banner.png""");
	            InputStream triangle_input_stream = triangle_file.read();
	            var triangle_pixbuf = new Gdk.Pixbuf.from_stream_at_scale(triangle_input_stream, 75, 75, true);
	            triangle = new Gtk.Image.from_pixbuf(triangle_pixbuf);

	            // Align everything to the top right corner
				triangle.set_alignment(1, 0);
				image.set_alignment(1,0);

				triangle_overlay = new Gtk.Overlay();
				count_overlay = new Gtk.Overlay();

				// Partially set up the overlays
				count_overlay.add(triangle);
				triangle_overlay.add(image);

			} catch (Error e) {
				critical("Unable to load podcast cover art.");
			}

			if(triangle_overlay == null)
				triangle_overlay = new Gtk.Overlay();
			if(count_overlay == null)
				count_overlay = new Gtk.Overlay();

			// Create a label to display the number of new episodes
			count_label = new Gtk.Label("<b>10</b>");
			count_label.use_markup = true;
			Granite.Widgets.Utils.apply_text_style_to_label (TextStyle.H2, count_label);
			count_label.set_alignment(1,0);
			count_label.margin_right = 5;


			// Add a tooltip
			this.tooltip_text = podcast.name.replace("%27", "'");

			// Set up the overlays

			count_overlay.add_overlay(count_label);
			triangle_overlay.add_overlay(count_overlay);

/*
 *	The code below shows the media type (audio/video) overlayed if the show_mimetype
 *	boolean value is set to true. I have since decided that it's too cluttered and
 *	doesn't provide any real additional value.
 */

/*
			if(show_mimetype) {

				Gtk.Overlay mimetype_overlay = new Gtk.Overlay();
				mimetype_overlay.add(triangle_overlay);


				Gtk.Image mime_image;
				if(podcast.content_type == MediaType.AUDIO)
					mime_image = new Gtk.Image.from_icon_name ("media-audio-symbolic", IconSize.BUTTON);
				else
					mime_image = new Gtk.Image.from_icon_name ("media-video-symbolic", IconSize.BUTTON);

string css = """
* {
	color: #e5e5e5;
	icon-shadow: 2px 2px #2a2a2a;
}
""";
				Gtk.CssProvider provider = new Gtk.CssProvider();
				provider.load_from_data(css, css.length);
				mime_image.get_style_context().add_provider(provider, 1);

				mime_image.set_alignment((float)0.05, (float)0.95);

				mimetype_overlay.add_overlay(mime_image);

				this.pack_start(mimetype_overlay, false, false, 0);

			} else {
*/
				this.pack_start(triangle_overlay, false, false, 0);
//				}

			this.valign = Align.START;
			image.set_no_show_all(false);
			image.show();

			show_all();
		}

		/*
		 * Creates a pixbuf given an InputStream
		 */
        public Gdk.Pixbuf create_cover_image (InputStream input_stream) {
            var cover_image = new Gdk.Pixbuf.from_stream (input_stream);

            if (cover_image.height == cover_image.width)
                cover_image = cover_image.scale_simple (COVER_SIZE, COVER_SIZE, Gdk.InterpType.BILINEAR);

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
			count_label.set_no_show_all(true);
			count_label.hide();
			triangle.set_no_show_all(true);
			triangle.hide();
		}
	
		/*
		 * Sets the banner count
		 */
		public void set_count(int count)
		{
			count_label.use_markup = true;
			count_label.set_markup("<span foreground='white'><b>%d</b></span>".printf(count));
			count_label.get_style_context().add_class("text-shadow");

		}
		
		/*
		 * Shows the banner and the count
		 */
		public void show_count()
		{
			count_label.set_no_show_all(false);
			count_label.show();
			triangle.set_no_show_all(false);
			triangle.show();
		}
	}
}
