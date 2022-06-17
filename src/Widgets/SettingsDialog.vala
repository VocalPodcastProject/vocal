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

using Gtk;

namespace Vocal {

    public class SettingsDialog : Gtk.Dialog {

        public signal void show_name_label_toggled ();

        private Gtk.Label keep_playing_in_background_label;
        private Gtk.Switch keep_playing_in_background_switch;

        private Gtk.Label autodownload_new_label;
        private Gtk.Switch autodownload_new;

        private Gtk.Label autoclean_label;
        private Gtk.Switch autoclean;

        private Gtk.Label show_name_label_label;
        private Gtk.Switch show_name_label_switch;

        private Gtk.Label backward_interval_label;
        private Gtk.SpinButton backward_spinner;

        private Gtk.Label forward_interval_label;
        private Gtk.SpinButton forward_spinner;

        public Gtk.Box content_box;
        private VocalSettings settings;

        /*
         * Constructor for a settings dialog given the current settings
         * and a parent window the set the dialog relative to
         */
        public SettingsDialog (Gtk.Window parent) {

            title = _ ("Preferences");
            this.settings = VocalSettings.get_default_instance();

            this.modal = true;
            this.resizable = false;
            this.set_transient_for (parent);
            content_box = get_content_area () as Gtk.Box;
            content_box.homogeneous = false;
            content_box.set_spacing (12);
            Utils.set_margins (content_box, 24);

            // Theme picker
            var theme_label = new Gtk.Label("Theme:");
            theme_label.halign = Gtk.Align.START;
            theme_label.hexpand = true;

            Gtk.ListStore theme_store = new Gtk.ListStore (1, typeof (string));
            Gtk.TreeIter theme_iter;
            theme_store.append (out theme_iter);
            theme_store.set (theme_iter, 0, "Use System Theme");
            theme_store.append (out theme_iter);
            theme_store.set(theme_iter, 0, "Dark");
            theme_store.append (out theme_iter);
            theme_store.set(theme_iter, 0, "Light");

            var theme_combo = new Gtk.ComboBox.with_model (theme_store);
            var theme_renderer= new CellRendererText();
            theme_combo.pack_start(theme_renderer, true);
            theme_combo.add_attribute (theme_renderer, "text", 0);

            if(settings.theme_preference == "system") {
                theme_combo.active = 0;
            } else if (settings.theme_preference == "dark") {
                theme_combo.active = 1;
            } else {
                theme_combo.active = 2;
            }

            theme_combo.changed.connect(() => {
                if (theme_combo.active == 0) {
                    settings.theme_preference = "system";
                } else if (theme_combo.active == 1) {
                    settings.theme_preference = "dark";
                } else {
                    settings.theme_preference = "light";
                }
            });

            var theme_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            theme_box.append(theme_label);
            theme_box.append(theme_combo);
            content_box.append(theme_box);


            Gtk.Separator theme_spacer = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            theme_spacer.hexpand = false;
            theme_spacer.margin_top = 12;
            theme_spacer.margin_bottom = 12;
            content_box.append (theme_spacer);


            // Keep playing in background option
            keep_playing_in_background_label = new Gtk.Label (_("Keep playing podcasts when the window is closed:"));
            keep_playing_in_background_label.halign = Gtk.Align.START;
            keep_playing_in_background_label.hexpand = true;

            keep_playing_in_background_switch = new Gtk.Switch ();
            keep_playing_in_background_switch.set_active (settings.keep_playing_in_background);
            keep_playing_in_background_switch.notify["active"].connect (() => {
                settings.keep_playing_in_background = keep_playing_in_background_switch.active;
            });
            keep_playing_in_background_label.set_mnemonic_widget(keep_playing_in_background_switch);

            var keep_playing_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            keep_playing_box.append (keep_playing_in_background_label);
            keep_playing_box.append (keep_playing_in_background_switch);
            content_box.append (keep_playing_box);

            // Autodownload option
            autodownload_new_label = new Gtk.Label (_ ("Automatically download new episodes:"));
            autodownload_new_label.halign = Gtk.Align.START;
            autodownload_new_label.hexpand = true;

            autodownload_new = new Gtk.Switch ();
            autodownload_new.set_active (settings.auto_download);
            autodownload_new.notify["active"].connect (() => {
                settings.auto_download = autodownload_new.active;
            });
            autodownload_new_label.set_mnemonic_widget(autodownload_new);

            var autodownload_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            autodownload_box.append (autodownload_new_label);
            autodownload_box.append (autodownload_new);
            content_box.append (autodownload_box);

            // Autoclean option
            autoclean_label = new Gtk.Label (_ ("Keep my library clean:"));
            autoclean_label.halign = Gtk.Align.START;
            autoclean_label.hexpand = true;

            autoclean = new Gtk.Switch ();
            autoclean.set_active (settings.autoclean_library);
            autoclean.notify["active"].connect (() => {
                settings.autoclean_library = autoclean.active;
            });
            autoclean_label.set_mnemonic_widget(autoclean);

            var autoclean_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            autoclean_box.spacing = 5;
            autoclean_box.append (autoclean_label);
            autoclean_box.append (autoclean);
            content_box.append (autoclean_box);

            // Show name label option
            show_name_label_label = new Gtk.Label (_ ("Show podcast names below cover art:"));
            show_name_label_label.halign = Gtk.Align.START;
            show_name_label_label.hexpand = true;

            show_name_label_switch = new Gtk.Switch ();
            show_name_label_switch.set_active (settings.show_name_label);
            show_name_label_switch.notify["active"].connect (() => {
                settings.show_name_label = show_name_label_switch.active;
                show_name_label_toggled ();
            });
            show_name_label_label.set_mnemonic_widget(show_name_label_switch);

            var show_label_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            show_label_box.append (show_name_label_label);
            show_label_box.append (show_name_label_switch);
            content_box.append (show_label_box);


            Gtk.Separator check_spacer = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            check_spacer.hexpand = false;
            check_spacer.margin_top = 12;
            check_spacer.margin_bottom = 12;
            content_box.append (check_spacer);

            // Skip options
            var backward_interval_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            backward_interval_label = new Gtk.Label (_ ("Seconds to skip back:"));
            backward_interval_label.hexpand = true;
            backward_interval_label.halign = Gtk.Align.START;

            backward_spinner = new Gtk.SpinButton.with_range (0, 240, 15);
            backward_spinner.value = (double)settings.rewind_seconds;
            backward_spinner.value_changed.connect (() => {
                settings.rewind_seconds = (int) backward_spinner.value;
            });
            backward_spinner.halign = Gtk.Align.END;
            backward_interval_label.set_mnemonic_widget(backward_spinner);

            backward_interval_box.append (backward_interval_label);
            backward_interval_box.append (backward_spinner);

            content_box.append (backward_interval_box);

            var forward_interval_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            forward_interval_label = new Gtk.Label (_ ("Seconds to skip forward:"));
            forward_interval_label.hexpand = true;
            forward_interval_label.halign = Gtk.Align.START;

            forward_spinner = new Gtk.SpinButton.with_range (0, 240, 15);
            forward_spinner.value = (double)settings.fast_forward_seconds;
            forward_spinner.value_changed.connect (() => {
                settings.fast_forward_seconds = (int) forward_spinner.value;
            });
            forward_spinner.halign = Gtk.Align.END;
            forward_interval_label.set_mnemonic_widget(forward_spinner);

            forward_interval_box.append (forward_interval_label);
            forward_interval_box.append (forward_spinner);
            content_box.append (forward_interval_box);

            // iTunes County Codes
            Gtk.ListStore list_store = new Gtk.ListStore (1, typeof (string));
            Gtk.TreeIter iter;
            int active_pos = 0, i = 0;

            var cc = Utils.get_itunes_country_codes ();
            GLib.List<string> list = new GLib.List<string> ();
            foreach (string s in cc.values) {
                list.append (s);
            }
            list.sort ((a, b) => {
                int pos;
                if (a < b) { pos = 0; } else { pos = 1; }
                return pos;
            });

            // Find the matching value in the list for the current setting
            string current_store_id = cc.get (this.settings.itunes_store_country);

            foreach (string s in list) {
                list_store.append (out iter);
                list_store.set (iter, 0, s);
                if (s == current_store_id) {
                    active_pos = i;
                }
                i++;
            }

            var itunes_country_label = new Gtk.Label (_ ("Show iTunes Store results from:"));
            itunes_country_label.justify = Gtk.Justification.LEFT;
            itunes_country_label.set_property ("xalign", 0);

            var combo_box = new Gtk.ComboBox.with_model (list_store);
            Gtk.CellRendererText renderer = new Gtk.CellRendererText ();
            combo_box.pack_start (renderer, true);
            combo_box.add_attribute (renderer, "text", 0);
            combo_box.active = active_pos;
            itunes_country_label.set_mnemonic_widget(combo_box);

            combo_box.changed.connect (() => {
                int active = combo_box.active;
                string new_setting = list.nth (active).data;

                foreach (string st in cc.keys) {
                    if (cc.get (st) == new_setting) {
                        this.settings.itunes_store_country = st;
                        break;
                    }
                }
            });

            Gtk.Separator store_spacer = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            store_spacer.hexpand = false;
            store_spacer.margin_top = 12;
            store_spacer.margin_bottom = 12;
            content_box.append (store_spacer);

            content_box.append (itunes_country_label);
            content_box.append (combo_box);

            this.response.connect((response) => {
                hide();
            });
        }
    }
}
