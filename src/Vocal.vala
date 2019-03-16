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
using Granite;
using Granite.Services;

namespace Vocal {

	namespace Option {
		private static bool OPEN_HIDDEN = false;
	}

    public class VocalApp : Granite.Application {

        private Controller controller = null;
        public string[] args;

        construct {
            program_name = "Vocal";
            exec_name = "vocal";

            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;

            app_years = "2015-2019";
            app_icon = "com.github.needle-and-thread.vocal";
            app_launcher = "com.github.needle-and-thread.vocal.desktop";
            application_id = "com.github.needle-and-thread.vocal";

            main_url = "https://vocalproject.net";
            bug_url = "https://github.com/needle-and-thread/vocal/issues";
            help_url = "https://vocalproject.net";
            translate_url = "https://www.transifex.com/needle-and-thread/vocal/";

            about_authors = { "Nathan Dyer <mail@nathandyer.me>" };
            about_documenters = { "Nathan Dyer <mail@nathandyer.me>" };
            about_artists = { "Nathan Dyer (App) <mail@nathandyer.me>", "Harvey Cabaguio (Icons and Branding) <harvey@elementaryos.org", "Mashnoon Ibtesum (Artwork)" };
            about_comments = "Podcast Client for the Modern Desktop";
            about_translators = _("translator-credits");
            about_license_type = Gtk.License.GPL_3_0;

            set_options();
        }

        public const OptionEntry[] app_options = {
            { "hidden", 'h', 0, OptionArg.NONE, out Option.OPEN_HIDDEN, "Open without displaying the window so podcasts will continue to update", null },
            { null }
        };


        public VocalApp () {
            Logger.initialize ("Vocal");
            Logger.DisplayLevel = LogLevel.INFO;
        }

        public override void activate () {
        
            if (controller == null) {
                controller = new Controller(this);
            }

            if (get_windows () == null) {
                controller.window = new MainWindow (controller);
                controller.open_hidden = Option.OPEN_HIDDEN;
                if(!Option.OPEN_HIDDEN)
                	controller.window.show_all ();
            } else {
                controller.window.present ();
            }
        }

        public static void main (string [] args) {
            X.init_threads ();

            // Options

            var context = new OptionContext ();
    		context.add_main_entries (app_options, "vocal");
        	context.add_group (Gtk.get_option_group (true));

        	try {
	            context.parse (ref args);
	        } catch (Error e) {
	            warning (e.message);
	        }

            // Init internationalization support
            string package_name = Constants.GETTEXT_PACKAGE;
            Intl.setlocale (LocaleCategory.ALL, "");
            Intl.bindtextdomain (package_name, Constants.DATADIR + "/locale");
            Intl.bind_textdomain_codeset (package_name, "UTF-8");
            Intl.textdomain (package_name);

            // Initialize GtkClutter
            var err = GtkClutter.init (ref args);
            if (err != Clutter.InitError.SUCCESS) {
                stdout.puts("Could not initialize clutter gtk\n");
                error ("Could not initalize clutter! "+err.to_string ());
            }

            // Initialize Clutter
            err = Clutter.init (ref args);
            if (err != Clutter.InitError.SUCCESS) {
                stdout.puts("Could not initialize clutter.\n");
                error ("Could not initalize clutter! "+err.to_string ());
            }

            // Initialize GStreamer
            Gst.init (ref args);
            Gst.PbUtils.init();

            // Set the media role
            GLib.Environ.set_variable ({"PULSE_PROP_media.role"}, "audio", "true");

			// Create a new instance of the app and run it
            var app = new Vocal.VocalApp ();
            app.args = args;
            app.run (args);
        }
    }
}
