/* Copyright 2014-2022 Nathan Dyer and Vocal Project Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

int main (string[] args) {
    // Init internationalization support
    string package_name = Constants.GETTEXT_PACKAGE;
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (package_name, Constants.DATADIR + "/locale");
    Intl.bind_textdomain_codeset (package_name, "UTF-8");
    Intl.textdomain (package_name);

    // Initialize GStreamer
    Gst.init (ref args);
    Gst.PbUtils.init ();

    // Set the media role
    GLib.Environ.set_variable ({"PULSE_PROP_media.role"}, "audio", "true");

    var app = new Vocal.Application ();
    return app.run (args);
}
