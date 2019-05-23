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

    public class SettingsDialog : Gtk.Dialog{

        public signal void      show_name_label_toggled();
        
        private Gtk.Label       keep_playing_in_background_label;
        private Gtk.Switch      keep_playing_in_background_switch;
    
        private Gtk.Label       autodownload_new_label;
        private Gtk.Switch      autodownload_new;
        
        private Gtk.Label       autoclean_label;
        private Gtk.Switch      autoclean;

        private Gtk.Label       show_name_label_label;
        private Gtk.Switch      show_name_label_switch;
        
        private Gtk.Label       backward_interval_label;
        private Gtk.SpinButton  backward_spinner;
        
        private Gtk.Label       forward_interval_label;
        private Gtk.SpinButton  forward_spinner;
        
        private Gtk.Label       archive_access_key_label;
        private Gtk.Entry       archive_access_key_entry;
        
        private Gtk.Label       archive_secret_key_label;
        private Gtk.Entry       archive_secret_key_entry;
        
        
        public Gtk.Box content_box;
        private VocalSettings settings;
        
        /*
         * Constructor for a settings dialog given the current settings
         * and a parent window the set the dialog relative to
         */
        public SettingsDialog(VocalSettings settings, Gtk.Window parent) {
            
            title = _("Preferences");
            this.settings = settings; 
            

            (get_header_bar () as Gtk.HeaderBar).show_close_button = false;
            get_header_bar ().get_style_context ().remove_class ("header-bar");

            this.modal = true;
            this.resizable = false;
            this.set_transient_for(parent);
            content_box = get_content_area () as Gtk.Box;
            content_box.homogeneous = false;
            content_box.margin = 12;
            content_box.spacing = 6;
            
            // Keep playing in background option
            keep_playing_in_background_label = new Gtk.Label (_("Keep playing podcasts when the window is closed:"));
            keep_playing_in_background_label.justify = Gtk.Justification.LEFT;
            keep_playing_in_background_label.set_property ("xalign", 0);
            
            keep_playing_in_background_switch = new Gtk.Switch ();
            keep_playing_in_background_switch.set_active (settings.keep_playing_in_background);
            keep_playing_in_background_switch.notify["active"].connect (() => {
                settings.keep_playing_in_background = keep_playing_in_background_switch.active;
		    });
            
            var keep_playing_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            keep_playing_box.spacing = 5;
            keep_playing_box.pack_start (keep_playing_in_background_label, true, true, 0);
            keep_playing_box.pack_start (keep_playing_in_background_switch, false, false, 0);
            content_box.add (keep_playing_box);
            
            // Autodownload option
            autodownload_new_label = new Gtk.Label(_("Automatically download new episodes:"));
            autodownload_new_label.justify = Gtk.Justification.LEFT;
            autodownload_new_label.set_property("xalign", 0);
            
            autodownload_new = new Gtk.Switch();
            
            autodownload_new.set_active(settings.auto_download);
            autodownload_new.notify["active"].connect (() => {
                settings.auto_download = autodownload_new.active;
		    });
            
            var autodownload_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            autodownload_box.spacing = 5;
            autodownload_box.pack_start(autodownload_new_label, true, true, 0);
            autodownload_box.pack_start(autodownload_new, false, false, 0);
            content_box.add(autodownload_box);
            
            // Autoclean option
            autoclean_label = new Gtk.Label(_("Keep my library clean:"));
            autoclean_label.justify = Gtk.Justification.LEFT;
            autoclean_label.set_property("xalign", 0);
            
            autoclean = new Gtk.Switch();
            
            autoclean.set_active(settings.autoclean_library);
            autoclean.notify["active"].connect (() => {
                settings.autoclean_library = autoclean.active;
		    });
            
            var autoclean_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            autoclean_box.spacing = 5;
            autoclean_box.pack_start(autoclean_label, true, true, 0);
            autoclean_box.pack_start(autoclean, false, false, 0);
            content_box.add(autoclean_box);

            // Show name label option
            show_name_label_label = new Gtk.Label(_("Show podcast names below cover art:"));
            show_name_label_label.justify = Gtk.Justification.LEFT;
            show_name_label_label.set_property("xalign", 0);

            show_name_label_switch = new Gtk.Switch();
            show_name_label_switch.set_active(settings.show_name_label);
            show_name_label_switch.notify["active"].connect (() => {
                settings.show_name_label = show_name_label_switch.active;
                show_name_label_toggled();
            });

            var show_label_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            show_label_box.spacing = 5;
            show_label_box.pack_start(show_name_label_label, true, true, 0);
            show_label_box.pack_start(show_name_label_switch, false, false, 0);
            content_box.add(show_label_box);
            
            
		    Gtk.Separator check_spacer = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            check_spacer.expand = false;
            check_spacer.margin_top = 12;
            check_spacer.margin_bottom = 12;
            content_box.add(check_spacer);
            
            // Skip options
		    var backward_interval_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		  
		    backward_interval_label = new Gtk.Label(_("Seconds to skip back:"));
		    backward_interval_label.justify = Gtk.Justification.LEFT;
		    backward_interval_label.halign = Gtk.Align.START;
		    
		    backward_spinner = new Gtk.SpinButton.with_range (0, 240, 15);
		    backward_spinner.value = (double)settings.rewind_seconds;
		    backward_spinner.value_changed.connect(() => {
		        settings.rewind_seconds = (int) backward_spinner.value;
		    });
            backward_spinner.halign = Gtk.Align.END;
		    
		    backward_interval_box.pack_start(backward_interval_label, true, true, 0);
		    backward_interval_box.pack_start(backward_spinner, false, false, 0);
		    
		    content_box.add(backward_interval_box);
		    
		    var forward_interval_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		    
		    forward_interval_label = new Gtk.Label(_("Seconds to skip forward:"));
		    forward_interval_label.justify = Gtk.Justification.LEFT;
		    forward_interval_label.halign = Gtk.Align.START;
		    
		    forward_spinner = new Gtk.SpinButton.with_range(0, 240, 15);
		    forward_spinner.value = (double)settings.fast_forward_seconds;
		    forward_spinner.value_changed.connect(() => {
		        settings.fast_forward_seconds = (int) forward_spinner.value;
		    });
		    forward_spinner.halign = Gtk.Align.END;

		    forward_interval_box.pack_start(forward_interval_label, true, true, 0);
		    forward_interval_box.pack_start(forward_spinner, false, false, 0);
		    content_box.add(forward_interval_box);
		    
            // iTunes County Codes
            Gtk.ListStore list_store = new Gtk.ListStore (1, typeof(string));
            Gtk.TreeIter iter;
            int active_pos = 0, i = 0;

            var cc = Utils.get_itunes_country_codes();
            GLib.List<string> list = new GLib.List<string>();
            foreach(string s in cc.values) {
                list.append(s);
            }     
            list.sort((a,b) => {
                int pos;
                if (a < b) { pos = 0; } else { pos = 1; }
                return pos;
            });

            // Find the matching value in the list for the current setting
            string current_store_id = cc.get(this.settings.itunes_store_country);

            foreach(string s in list) {
                list_store.append (out iter);
                list_store.set (iter, 0, s);
                if(s == current_store_id) {
                    active_pos = i;
                }
                i++;
            }

            var itunes_country_label = new Gtk.Label(_("Show iTunes Store results from:"));
            itunes_country_label.justify = Gtk.Justification.LEFT;
            itunes_country_label.set_property("xalign", 0);

            var combo_box = new Gtk.ComboBox.with_model(list_store);
            Gtk.CellRendererText renderer = new Gtk.CellRendererText ();
            combo_box.pack_start (renderer, true);
            combo_box.add_attribute (renderer, "text", 0);
            combo_box.active = active_pos;

            // When the combo box changes, save the setting
            combo_box.changed.connect(() => {
                int active = combo_box.active;
                string new_setting = list.nth(active).data;

                foreach(string st in cc.keys) {
                    if(cc.get(st) == new_setting) {
                        this.settings.itunes_store_country = st;
                        break;
                    }
                }
            });

            Gtk.Separator store_spacer = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            store_spacer.expand = false;
            store_spacer.margin_top = 12;
            store_spacer.margin_bottom = 12;
            content_box.add(store_spacer);

            content_box.add(itunes_country_label);
            content_box.add(combo_box);
            
            Gtk.Separator archive_spacer = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            archive_spacer.expand = false;
            archive_spacer.margin_top = 12;
            content_box.add (archive_spacer);
            
            
            var archive_api_key_linkbutton = new Gtk.LinkButton.with_label ("https://archive.org/account/s3.php", "See your archive.org API keys");
            
            archive_access_key_label = new Gtk.Label (_("Archive.org S3 Access Key"));
            archive_access_key_label.justify = Gtk.Justification.LEFT;
		    archive_access_key_label.halign = Gtk.Align.START;
            archive_access_key_entry = new Gtk.Entry ();
            archive_access_key_entry.set_text (settings.archive_access_key);
            archive_access_key_entry.changed.connect ( () => {
                settings.archive_access_key = archive_access_key_entry.text;
            });
            
            archive_secret_key_label = new Gtk.Label (_("Archive.org S3 Secret Key"));
            archive_secret_key_label.justify = Gtk.Justification.LEFT;
		    archive_secret_key_label.halign = Gtk.Align.START;
            archive_secret_key_entry = new Gtk.Entry ();
            archive_secret_key_entry.set_text (settings.archive_secret_key);
            archive_secret_key_entry.changed.connect ( () => {
                settings.archive_secret_key = archive_secret_key_entry.text;
            });
            
            content_box.add (archive_api_key_linkbutton);
            content_box.add (archive_access_key_label);
            content_box.add (archive_access_key_entry);
            content_box.add (archive_secret_key_label);
            content_box.add (archive_secret_key_entry);
            
            var close_button = new Gtk.Button.with_label (_("Close"));
            close_button.clicked.connect(() => {
                destroy();
            });

            var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            button_box.set_layout (Gtk.ButtonBoxStyle.END);
            button_box.pack_end (close_button);

            content_box.pack_end (button_box);
            
            this.set_size_request (50, 50);
        }
    }
}
