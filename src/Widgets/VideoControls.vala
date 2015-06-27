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

    public class VideoControls : Gtk.Revealer {
    
        public signal void play_toggled ();					// Fired when the play button gets clicked
        public signal void unfullscreen ();					// Fired when the unfullscreen button gets clicked
        public signal void progress_bar_scale_changed();	// Fired when the progress bar scale changes (user seeks position)			

        public double progress_bar_fill;					// The value currently set in the progress bar

        public Gtk.Button play_button;
        private Gtk.Button unfullscreen_button;

        private PlaybackBox playback_box;

        public VideoControls () {
            transition_type = Gtk.RevealerTransitionType.CROSSFADE;
            var main_actionbar = new Gtk.ActionBar ();

            play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            play_button.tooltip_text = _("Play");
            play_button.clicked.connect (() => {play_toggled ();});

            main_actionbar.pack_start (play_button);

            playback_box = new PlaybackBox();
            playback_box.scale_changed.connect(() => {

                progress_bar_fill = playback_box.get_progress_bar_fill();
                progress_bar_scale_changed();
            });

            playback_box.margin_top = 10;
            playback_box.margin_bottom = 5;
            playback_box.margin_left = 20;
            playback_box.margin_right = 20;

            unfullscreen_button = new Gtk.Button.from_icon_name("window-restore-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            unfullscreen_button.clicked.connect(() => { unfullscreen(); });
            unfullscreen_button.tooltip_text = _("Exit Fullscreen");

            main_actionbar.pack_start(playback_box);
            main_actionbar.pack_start(unfullscreen_button);
            add (main_actionbar);

            show_all ();
        }

		/*
		 * Sets the progress
		 */
        public void set_progress(double percentage, int mins_remaining, int secs_remaining, int mins_elapsed, int secs_elapsed) {
            playback_box.set_progress(percentage, mins_remaining, secs_remaining, mins_elapsed, secs_elapsed);

        }
	
		/*
		 * Sets the info title
		 */
        public void set_info_title(string title, string podcast_name) {
            playback_box.set_info_title(title, podcast_name);
        }
    }
}
