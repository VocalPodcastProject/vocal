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
    public abstract void GrabMediaPlayerKeys (string application, uint32 time) throws GLib.IOError;  // vala-lint=line-length, naming-convention
    public abstract void ReleaseMediaPlayerKeys (string application) throws GLib.IOError;  // vala-lint=line-length, naming-convention
    public signal void MediaPlayerKeyPressed (string application, string key);
}

public class Utils {

    public static bool check_elementary () {
        string output;
        output = GLib.Environment.get_variable ("XDG_CURRENT_DESKTOP");
        string icon_name = Gtk.Settings.get_default ().gtk_icon_theme_name;

        if (output != null && output.contains ("Pantheon") && icon_name.contains ("elementary")) {
            return true;
        } else {
            return false;
        }
    }

    /*
     * A convenience method that sends a generic notification with a message and title
     * (assuming libnotify is enabled)
     */
    public static void send_generic_notification (string message, string? title = "Vocal") {
#if HAVE_LIBNOTIFY
        var notification = new Notify.Notification (title, message, "vocal");
        notification.show ();
#endif
    }

    /*
    * Find the real URI for a resource (locates redirected URIs, etc)
    *
    * Code primarily taken from a patch by
    * Olivier Duchateau <duchateau.olivierd@gmail.com>
    */
    public static string get_real_uri (string resource) {
        Soup.Session session;
        Soup.Message msg;
        string new_url = null;

        /* Create Soup objects */
        session = new Soup.Session ();
        session.user_agent = Constants.USER_AGENT;
        msg = new Soup.Message ("GET", resource);

        /* Signal */
        msg.got_headers.connect (() => {
            /* 302 */
            if (msg.status_code == Soup.Status.FOUND) {
                new_url = msg.response_headers.get_one ("Location");
                /* Finish processing request */
                session.cancel_message (msg, Soup.Status.CANCELLED);
            }
        });

        session.send_message (msg);

        if (new_url == null) {
           new_url = "%s".printf (resource);
        }

        return new_url;
    }

    /*
     * Strips a string of HTML tags, except for ones that are useful in markup
     */
    public static string html_to_markup (string original) {

        string markup = GLib.Uri.unescape_string (original);

        if ( markup == null ) {
            markup = original;
        }

        markup = markup.replace ("&", "&amp;");

        // Simplify (keep only href attribute) & preserve anchor tags.
        Regex simpleLinks = new Regex ("<a (.*? (href[\\s=]*?\".*?\").*?)> (.*?)<[\\s\\/]*?a[\\s>]*",
                                      RegexCompileFlags.CASELESS | RegexCompileFlags.DOTALL);
        markup = simpleLinks.replace (markup, -1, 0, "?a? \\2?a-end?\\3 ?/a?");

        // Replace <br> tags with line breaks.
        Regex lineBreaks = new Regex ("<br[\\s\\/]*?>", RegexCompileFlags.CASELESS);
        markup = lineBreaks.replace (markup, -1, 0, "\n");

        markup = markup.replace ("<a", "?a?");
        markup = markup.replace ("</a>", "?/a?");

        // Preserve bold tags
        markup = markup.replace ("<b>", "?b?");
        markup = markup.replace ("</b>", "?/b?");

        int nextOpenBracketIndex = 0;
        int nextCloseBracketIndex = 0;
        while (nextOpenBracketIndex >= 0) {
            nextOpenBracketIndex = markup.index_of ("<", 0);
            nextCloseBracketIndex = markup.index_of (">", nextOpenBracketIndex) + 1;
            if (
                nextOpenBracketIndex < nextCloseBracketIndex && nextOpenBracketIndex >= 0
                && nextCloseBracketIndex >= 0
                && nextOpenBracketIndex <= markup.length
                && nextCloseBracketIndex <= markup.length
            ) {
                markup = markup.splice (nextOpenBracketIndex, nextCloseBracketIndex);
                nextOpenBracketIndex = 0;
                nextCloseBracketIndex = 0;
            } else {
                nextOpenBracketIndex = -1;
            }
        }

        // remaining < & > tags are translated
        markup = markup.replace ("<", "&lt;");
        markup = markup.replace (">", "&gt;");

        // Preserve hyperlinks
        markup = markup.replace ("?a?", "<a");
        markup = markup.replace ("?a-end?", ">");
        markup = markup.replace ("?/a?", "</a>");

        // Preserve bold tags
        markup = markup.replace ("?b?", "<b>");
        markup = markup.replace ("?/b?", "</b>");

        if (markup != null && markup.length > 0)
            return markup;
        else
            return markup;

    }

    public static Gee.HashMap<string, string> get_itunes_country_codes () {
        Gee.HashMap<string, string> code_map = new Gee.HashMap<string, string> ();
        code_map.set ("ae", "United Arab Emirates");
        code_map.set ("ag", "Antigua and Barbuda");
        code_map.set ("ai", "Anguilla");
        code_map.set ("al", "Albania");
        code_map.set ("am", "Armenia");
        code_map.set ("ao", "Angola");
        code_map.set ("ar", "Argentina");
        code_map.set ("at", "Austria");
        code_map.set ("au", "Australia");
        code_map.set ("az", "Azerbaijan");
        code_map.set ("bb", "Barbados");
        code_map.set ("be", "Belgium");
        code_map.set ("bf", "Burkina-Faso");
        code_map.set ("bg", "Bulgaria");
        code_map.set ("bh", "Bahrain");
        code_map.set ("bj", "Benin");
        code_map.set ("bm", "Bermuda");
        code_map.set ("bn", "Brunei Darussalam");
        code_map.set ("bo", "Bolivia");
        code_map.set ("br", "Brazil");
        code_map.set ("bs", "Bahamas");
        code_map.set ("bt", "Bhutan");
        code_map.set ("bw", "Botswana");
        code_map.set ("by", "Belarus");
        code_map.set ("bz", "Belize");
        code_map.set ("ca", "Canada");
        code_map.set ("cg", "Democratic Republic of the Congo");
        code_map.set ("ch", "Switzerland");
        code_map.set ("cl", "Chile");
        code_map.set ("cn", "China");
        code_map.set ("co", "Colombia");
        code_map.set ("cr", "Costa Rica");
        code_map.set ("cv", "Cape Verde");
        code_map.set ("cy", "Cyprus");
        code_map.set ("cz", "Czech Republic");
        code_map.set ("de", "Germany");
        code_map.set ("dk", "Denmark");
        code_map.set ("dm", "Dominica");
        code_map.set ("do", "Dominican Republic");
        code_map.set ("dz", "Algeria");
        code_map.set ("ec", "Ecuador");
        code_map.set ("ee", "Estonia");
        code_map.set ("eg", "Egypt");
        code_map.set ("es", "Spain");
        code_map.set ("fi", "Finland");
        code_map.set ("fj", "Fiji");
        code_map.set ("fm", "Federated States of Micronesia");
        code_map.set ("fr", "France");
        code_map.set ("gb", "Great Britain");
        code_map.set ("gd", "Grenada");
        code_map.set ("gh", "Ghana");
        code_map.set ("gm", "Gambia");
        code_map.set ("gr", "Greece");
        code_map.set ("gt", "Guatemala");
        code_map.set ("gw", "Guinea Bissau");
        code_map.set ("gy", "Guyana");
        code_map.set ("hk", "Hong Kong");
        code_map.set ("hn", "Honduras");
        code_map.set ("hr", "Croatia");
        code_map.set ("hu", "Hungaria");
        code_map.set ("id", "Indonesia");
        code_map.set ("ie", "Ireland");
        code_map.set ("il", "Israel");
        code_map.set ("in", "India");
        code_map.set ("is", "Iceland");
        code_map.set ("it", "Italy");
        code_map.set ("jm", "Jamaica");
        code_map.set ("jo", "Jordan");
        code_map.set ("jp", "Japan");
        code_map.set ("ke", "Kenya");
        code_map.set ("kg", "Krygyzstan");
        code_map.set ("kh", "Cambodia");
        code_map.set ("kn", "Saint Kitts and Nevis");
        code_map.set ("kr", "South Korea");
        code_map.set ("kw", "Kuwait");
        code_map.set ("ky", "Cayman Islands");
        code_map.set ("kz", "Kazakhstan");
        code_map.set ("la", "Laos");
        code_map.set ("lb", "Lebanon");
        code_map.set ("lc", "Saint Lucia");
        code_map.set ("lk", "Sri Lanka");
        code_map.set ("lr", "Liberia");
        code_map.set ("lt", "Lithuania");
        code_map.set ("lu", "Luxembourg");
        code_map.set ("lv", "Latvia");
        code_map.set ("md", "Moldova");
        code_map.set ("mg", "Madagascar");
        code_map.set ("mk", "Macedonia");
        code_map.set ("ml", "Mali");
        code_map.set ("mn", "Mongolia");
        code_map.set ("mo", "Macau");
        code_map.set ("mr", "Mauritania");
        code_map.set ("ms", "Montserrat");
        code_map.set ("mt", "Malta");
        code_map.set ("mu", "Mauritius");
        code_map.set ("mw", "Malawi");
        code_map.set ("mx", "Mexico");
        code_map.set ("my", "Malaysia");
        code_map.set ("mz", "Mozambique");
        code_map.set ("na", "Namibia");
        code_map.set ("ne", "Niger");
        code_map.set ("ng", "Nigeria");
        code_map.set ("ni", "Nicaragua");
        code_map.set ("nl", "Netherlands");
        code_map.set ("np", "Nepal");
        code_map.set ("no", "Norway");
        code_map.set ("nz", "New Zealand");
        code_map.set ("om", "Oman");
        code_map.set ("pa", "Panama");
        code_map.set ("pe", "Peru");
        code_map.set ("pg", "Papua New Guinea");
        code_map.set ("ph", "Philippines");
        code_map.set ("pk", "Pakistan");
        code_map.set ("pl", "Poland");
        code_map.set ("pt", "Portugal");
        code_map.set ("pw", "Palau");
        code_map.set ("py", "Paraguay");
        code_map.set ("qa", "Qatar");
        code_map.set ("ro", "Romania");
        code_map.set ("ru", "Russia");
        code_map.set ("sa", "Saudi Arabia");
        code_map.set ("sb", "Soloman Islands");
        code_map.set ("sc", "Seychelles");
        code_map.set ("se", "Sweden");
        code_map.set ("sg", "Singapore");
        code_map.set ("si", "Slovenia");
        code_map.set ("sk", "Slovakia");
        code_map.set ("sl", "Sierra Leone");
        code_map.set ("sn", "Senegal");
        code_map.set ("sr", "Suriname");
        code_map.set ("st", "Sao Tome e Principe");
        code_map.set ("sv", "El Salvador");
        code_map.set ("sz", "Swaziland");
        code_map.set ("tc", "Turks and Caicos Islands");
        code_map.set ("td", "Chad");
        code_map.set ("th", "Thailand");
        code_map.set ("tj", "Tajikistan");
        code_map.set ("tm", "Turkmenistan");
        code_map.set ("tn", "Tunisia");
        code_map.set ("tr", "Turkey");
        code_map.set ("tt", "Republic of Trinidad and Tobago");
        code_map.set ("tw", "Taiwan");
        code_map.set ("tz", "Tanzania");
        code_map.set ("ua", "Ukraine");
        code_map.set ("ug", "Uganda");
        code_map.set ("us", "United States of America");
        code_map.set ("uy", "Uruguay");
        code_map.set ("uz", "Uzbekistan");
        code_map.set ("vc", "Saint Vincent and the Grenadines");
        code_map.set ("ve", "Venezuela");
        code_map.set ("vg", "British Virgin Islands");
        code_map.set ("vn", "Vietnam");
        code_map.set ("ye", "Yemen");
        code_map.set ("za", "South Africa");
        code_map.set ("zw", "Zimbabwe");
        return code_map;
    }

    public static string get_shareable_link_for_episode (Vocal.Episode e) {
        string output = "http://needleandthread.co/apps/vocal/simpleshare.html?podcastName=%s&artUri=%s&episodeTitle=%s&mediaUri=%s";  // vala-lint=line-length
        string podcastName = GLib.Uri.escape_string (e.parent.name);
        string albumArt = e.parent.remote_art_uri;
        string episodeTitle = GLib.Uri.escape_string (e.title);
        string audioSource = e.uri;
        return output.printf (podcastName, albumArt, episodeTitle, audioSource);
    }

    /*
     * Takes HTML (most likely from show notes) and sets the background color, font family, and
     * font size so that it looks good in the podcast view.
     */
    public static string get_styled_html (string original_html) {

const string STYLE = """
<html>
<head>
<style>
h1 {
    background-color:#F8F8F8;
    font-family:'Open Sans';
    font-size:150%;
}
body {
    background-color:#F8F8F8;
    font-family:'Open Sans';
    font-size:80%;
}
</style>
</head>
<body>
""";

const string CLOSE = """
</body>
</html>""";

        return STYLE + original_html + CLOSE;

    }

    /*
     * Truncates a string if it is longer than to the n. Returns the string unchanged otherwise.
     */
    public static string truncate_string (string str, int n) {
        if (str.length > n) {
            return str.substring (0, n);
        }

        return str;
    }

    public static async bool upload_to_internet_archive (
        string local_uri,
        string title,
        string podcast,
        string description
    ) {

        info ("Uploading to internet archive");
        string container = Uri.escape_string (podcast.replace (" ", "-").replace (":", "").down ());
        if (container[container.len () - 1] == '-') {
            container = container.substring (0, container.len () - 1);
        }
        string episode = Uri.escape_string (
            title.replace (" ", "-").down () + local_uri.substring (local_uri.last_index_of ("."))
        );
        info (container);
        info (episode);
        var session = new Soup.Session ();
        var message = new Soup.Message ("PUT","http://s3.us.archive.org/%s/%s".printf (container, episode));

        SourceFunc callback = upload_to_internet_archive.callback;

        ThreadFunc<void*> run = () => {
            uint8[] file_contents;
            GLib.FileUtils.get_data (local_uri, out file_contents);
            string mime_type = get_mime_type_for_file (local_uri);
            message.set_request (mime_type, Soup.MemoryUse.STATIC, file_contents);
            var settings = VocalSettings.get_default_instance ();
            string accesskey = settings.archive_access_key;
            string secretkey = settings.archive_secret_key;
            message.request_headers.append ("x-archive-auto-make-bucket", "1");
            message.request_headers.append ("x-archive-meta-title", podcast);
            message.request_headers.append ("x-archive-meta-description", description);
            message.request_headers.append ("authorization", "LOW %s:%s".printf (accesskey, secretkey));
            session.send_message (message);
            Idle.add ((owned) callback);
            return null;
        };
        Thread.create<void*> (run, false);

        yield;

        info ("archive.org request status code: %u", message.status_code);
        info ((string) message.response_body.data);
        if (message.status_code == 200) {
            return true;
        } else {
            return false;
        }

    }

    public static string get_mime_type_for_file (string file_uri) {

        string extension = file_uri.down ().substring (file_uri.last_index_of ("."));

        // If all else fails, assume MP3
        string mime = "audio/mpeg3";
        switch (extension) {
            case ".mp3":
                mime = "audio/mpeg";
                break;
            case ".mp4":
                mime = "video/mp4";
                break;
            case ".mpeg":
                mime = "video/mpeg";
                break;
            case ".aac":
                mime = "audio/aac";
                break;
            case ".weba":
                mime = "audio/webm";
                break;
            case ".webm":
                mime = "video/webm";
                break;
            case ".oga":
                mime = "audio/ogg";
                break;
            case ".ogv":
                mime = "video/ogg";
                break;
            case ".mov":
                mime = "video/quicktime";
                break;
        }

        return mime;
    }

}
