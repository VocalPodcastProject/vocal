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
    class SettingsDialog : Gtk.Dialog{
    
        
        
        private Gtk.Label       autodownload_new_label;
        private Gtk.Switch      autodownload_new;
        
        private Gtk.Label       autoclean_label;
        private Gtk.Switch      autoclean;
        
        private Gtk.Label       backward_interval_label;
        private Gtk.SpinButton  backward_spinner;
        
        private Gtk.Label       forward_interval_label;
        private Gtk.SpinButton  forward_spinner;
        
        
        public Gtk.Box content_box;
        private VocalSettings settings;
        
        /*
         * Constructor for a settings dialog given the current settings
         * and a parent window the set the dialog relative to
         */
        public SettingsDialog(VocalSettings settings, Gtk.Window parent) {
            
            Object (use_header_bar: 1);
            title = _("Preferences");
            this.settings = settings; 

            (get_header_bar () as Gtk.HeaderBar).show_close_button = false;
            get_header_bar ().get_style_context ().remove_class ("header-bar");

            this.modal = true;
            this.set_transient_for(parent);
            content_box = get_content_area () as Gtk.Box;
            content_box.homogeneous = false;
            content_box.margin_left = 12;
            content_box.margin_right = 12;
            
            // Autodownload option
            autodownload_new_label = new Gtk.Label(_("Automatically download new episodes:"));
            autodownload_new_label.justify = Gtk.Justification.LEFT;
            autodownload_new_label.xalign = 0;
            autodownload_new_label.margin_left = 5;
            
            autodownload_new = new Gtk.Switch();
            
            autodownload_new.set_active(settings.auto_download);
            
            autodownload_new.notify["active"].connect (() => {
                settings.auto_download = autodownload_new.active;
		    });
            
            var autodownload_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            autodownload_box.spacing = 5;
            autodownload_box.margin_bottom = 10;
            autodownload_box.pack_start(autodownload_new_label, true, true, 0);
            autodownload_box.pack_start(autodownload_new, false, false, 0);
            content_box.add(autodownload_box);
            
            // Autoclean option
            autoclean_label = new Gtk.Label(_("Automatically delete played files:"));
            autoclean_label.justify = Gtk.Justification.LEFT;
            autoclean_label.xalign = 0;
            autoclean_label.margin_left = 5;
            
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
            
            
		    Gtk.Separator check_spacer = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            check_spacer.expand = true;
            check_spacer.margin = 5;
            check_spacer.margin_top = 10;
            check_spacer.margin_bottom = 10;
            content_box.add(check_spacer);
            
            // Skip options
		    var backward_interval_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		    
		    backward_interval_label = new Gtk.Label(_("Seconds to skip back:"));
		    backward_interval_label.justify = Gtk.Justification.LEFT;
		    backward_interval_label.xalign = 0;
		    backward_interval_label.margin_right = 5;
		    
		    
		    
		    backward_spinner = new Gtk.SpinButton.with_range (0, 240, 15);
		    backward_spinner.value = (double)settings.rewind_seconds;
		    backward_spinner.value_changed.connect(() => {
		        settings.rewind_seconds = (int) backward_spinner.value;
		    });
		    
		    backward_interval_box.pack_start(backward_interval_label, true, true, 0);
		    backward_interval_box.pack_start(backward_spinner, false, false, 0);
		    backward_interval_box.margin = 5;
		    
		    content_box.add(backward_interval_box);
		    
		    var forward_interval_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		    
		    forward_interval_label = new Gtk.Label(_("Seconds to skip forward:"));
		    forward_interval_label.justify = Gtk.Justification.LEFT;
		    forward_interval_label.xalign = 0;
		    forward_interval_label.margin_right = 5;
		    
		    forward_spinner = new Gtk.SpinButton.with_range(0, 240, 15);
		    forward_spinner.value = (double)settings.fast_forward_seconds;
		    forward_spinner.value_changed.connect(() => {
		        settings.fast_forward_seconds = (int) forward_spinner.value;
		    });
		    
		    forward_interval_box.pack_start(forward_interval_label, true, true, 0);
		    forward_interval_box.pack_start(forward_spinner, false, false, 0);
		    forward_interval_box.margin = 5;
		    content_box.add(forward_interval_box);
		    
		    
            var close_button = new Gtk.Button.with_label (_("Close"));
            close_button.clicked.connect(() => {
                destroy();
            });

            var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            button_box.set_layout (Gtk.ButtonBoxStyle.END);
            button_box.pack_end (close_button);
            button_box.margin_top = 12;

            content_box.add(button_box);

        }
    }
}
