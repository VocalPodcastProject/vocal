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

    public class DirectoryView : Gtk.Box {

        public signal void return_to_library();
        public signal void return_to_welcome();
        public signal void on_new_subscription(string url);

        private iTunesProvider itunes;
        private Gtk.FlowBox flowbox;
        private Gtk.Box banner_box;
        public  Gtk.Button return_button;
        public  Gtk.Button forward_button;
        private Gtk.Button first_run_continue_button;

        private Gtk.Box loading_box;

        private Gtk.ScrolledWindow scrolled_window;

        private bool top_podcasts_loaded = false;

        public DirectoryView(iTunesProvider itunes_provider, bool first_run = false) {

            this.set_orientation(Gtk.Orientation.VERTICAL);

            // Set up the banner

            banner_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            banner_box.get_style_context().add_class("toolbar");
            banner_box.get_style_context().add_class("library-toolbar");

            var itunes_title = new Gtk.Label(_("iTunes Top 100 Podcasts"));
            itunes_title.margin_top = 15;
            itunes_title.margin_bottom = 5;
            itunes_title.justify = Gtk.Justification.CENTER;
            itunes_title.expand = true;
            itunes_title.halign = Gtk.Align.CENTER;
            itunes_title.valign = Gtk.Align.CENTER;

            itunes_title.get_style_context ().add_class ("h2");

            if (first_run) {
                return_button = new Gtk.Button.with_label(_("Go Back"));
            } else  {
                return_button = new Gtk.Button.with_label(_("Return to Library"));
            }
            return_button.clicked.connect(() => { return_to_library (); });
            return_button.get_style_context().add_class("back-button");
            return_button.margin = 6;
            return_button.expand = false;
            return_button.halign = Gtk.Align.START;

            first_run_continue_button = new Gtk.Button.with_label(_("Done"));
            first_run_continue_button.get_style_context().add_class("suggested-action");
            first_run_continue_button.margin = 6;
            first_run_continue_button.expand = false;
            first_run_continue_button.halign = Gtk.Align.END;
            first_run_continue_button.clicked.connect(() => {
                return_button.label = _("Return to Library");
                hide_first_run_continue_button();
                return_to_library();
            });
            first_run_continue_button.sensitive = false;

            banner_box.pack_start(return_button, false, false, 0);
            banner_box.pack_end(first_run_continue_button, false, false, 0);

            if(!first_run) {
                hide_first_run_continue_button();
            }

            banner_box.vexpand = false;
            banner_box.hexpand = true;

            itunes_title.vexpand = false;
            itunes_title.hexpand  = true;

            this.itunes = itunes_provider;
            this.add(banner_box);
            this.add(itunes_title);
            
            loading_box = new  Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            var spinner = new Gtk.Spinner();
            spinner.active = true; 
            var loading_label = new Gtk.Label(_("Loading iTunes Store"));
            loading_label.get_style_context().add_class("h2");
            loading_box.add(loading_label);
            loading_box.add(spinner);
            this.pack_start(loading_box, true, true, 5);

            scrolled_window = new Gtk.ScrolledWindow(null, null);
            this.pack_start(scrolled_window, true, true, 15);

        }

        public async void load_top_podcasts() {
            SourceFunc callback = load_top_podcasts.callback;

            ThreadFunc<void*> run = () => {
                if(top_podcasts_loaded) {
                    info("Already loaded top 100 podcasts. Doing nothing.");
                    return null;
                }

                flowbox = new Gtk.FlowBox();

                // TODO: not actually asyncronous.
                info ("Getting top podcasts asynchronously?.");
                var entries = itunes.get_top_podcasts(100);
                info ("Top 100 podcasts loaded.");

                int i = 1;
                if(entries == null) {
                    info("iterating over entries");
                    return null;
                }

                foreach(DirectoryEntry entry in entries) {
                    DirectoryArt directory_art = new DirectoryArt(entry.itunesUrl, "%d. %s".printf(i, entry.title), entry.artist, entry.summary, entry.artworkUrl170);
                    directory_art.expand = false;
                    directory_art.subscribe_button_clicked.connect((url) => {
                        first_run_continue_button.sensitive = true;
                        on_new_subscription(url);
                    });
                    flowbox.add(directory_art);
                    i++;
                }

                top_podcasts_loaded = true;

                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);

            yield;

            loading_box.set_no_show_all(true);
            loading_box.hide();

            scrolled_window.add(flowbox);
            show_all();
        }

        public void show_first_run_continue_button() {
            first_run_continue_button.set_no_show_all(false);
            first_run_continue_button.show();
        }

        public void hide_first_run_continue_button() {
            first_run_continue_button.set_no_show_all(true);
            first_run_continue_button.hide();
        }

    }
}
