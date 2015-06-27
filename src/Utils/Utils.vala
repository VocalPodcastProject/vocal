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

[DBus (name = "org.gnome.SettingsDaemon.MediaKeys")]
public interface GnomeMediaKeys : GLib.Object {
    public abstract void GrabMediaPlayerKeys (string application, uint32 time) throws GLib.IOError;
    public abstract void ReleaseMediaPlayerKeys (string application) throws GLib.IOError;
    public signal void MediaPlayerKeyPressed (string application, string key);
}

public class Utils
{

	/*
	 * A convenience method that sends a generic notification with a message and title 
	 * (assuming libnotify is enabled)
	 */
    public static void send_generic_notification(string message, string? title = "Vocal")
    {
#if HAVE_LIBNOTIFY
        var notification = new Notify.Notification(title, message, "vocal");
        notification.show();
#endif
    }

	/* 
	 * Strips a string of HTML tags, except for ones that are useful in markup
	 */
    public static string html_to_markup(string original) {

        string markup, temp;

        markup = original.replace("%27", "'").replace("&nbsp;", "").replace("&rdquo;", "").replace("&rsquo;", "").replace("&ldquo;", "").replace("hellip;", "");

        markup.normalize();

        string split = "";

        int i = 0;
        int left_bracket_index, right_bracket_index;

        int end_of_tags_position = original.last_index_of(">");

        while(i < markup.length) {

            if(i < end_of_tags_position) {

                // Get the next left bracket index
                left_bracket_index = markup.index_of("<", i);
                right_bracket_index = markup.index_of(">", left_bracket_index);

                // At this point, i should be less than the end of tags position.
                // If not, it means that there is a close bracket without an open
                // bracket. It's rare, but it happens. If so, just return the original.
                if(left_bracket_index == -1) {
                    return markup;
                }

                // Keep from i to the beginning of the next tag
                temp = markup.slice(i, left_bracket_index);

                // Set i to the position right after the right bracket is found
                i = right_bracket_index + 1;
            } else {
                temp = markup.slice(i, markup.length);
                i = markup.length;
            }

            split += temp;
        }
        
        return split;

    }

}
