/***
  BEGIN LICENSE

  Copyright (C) 2014-2018 Nathan Dyer <mail@nathandyer.me>
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
using Gee;
using Granite;
namespace Vocal {

    public class NewEpisodesView : Gtk.Box {

        private Controller controller;
        private ListBox new_episodes_listbox;
        GLib.ListStore episodeListModel = new GLib.ListStore ( typeof (Episode) );
        public signal void go_back();
        public signal void play_episode_requested (Episode episode);
        public signal void add_all_new_to_queue (GLib.List<Episode> episodes);
        
        public NewEpisodesView (Controller cont) {
            controller = cont;
            
            var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            toolbar.get_style_context().add_class("toolbar");
            toolbar.get_style_context().add_class("library-toolbar");

            var go_back_button = new Gtk.Button.with_label(_("Your Podcasts"));
            go_back_button.clicked.connect(() => { go_back(); });
            go_back_button.get_style_context().add_class("back-button");
            go_back_button.margin = 6;
            
            toolbar.pack_start(go_back_button, false, false, 0);
            this.pack_start(toolbar, false, true, 0);
            
            var new_episodes_label = new Gtk.Label (_("New Episodes"));
            new_episodes_label.get_style_context ().add_class ("h2");
            new_episodes_label.margin_top = 12;
            this.pack_start(new_episodes_label, false, true, 0);
            
            var new_episodes_scrolled = new Gtk.ScrolledWindow (null, null);
            new_episodes_scrolled.margin_left = 50;
            new_episodes_scrolled.margin_right = 50;
            new_episodes_listbox = new Gtk.ListBox ();
            var add_all_to_queue_button = new Gtk.Button.with_label (_("Add all new episodes to the queue"));
            add_all_to_queue_button.halign = Gtk.Align.CENTER;
            add_all_to_queue_button.clicked.connect ( () => {
                GLib.List<Episode> episodes = new GLib.List<Episode>();
                for (int x = 0; ; x++) {
                    var e = (Episode) episodeListModel.get_item(x);
                    if (e == null) { break; } // No more items
                    episodes.append(e);
                }
                add_all_new_to_queue(episodes);
            });
            this.orientation = Gtk.Orientation.VERTICAL;
            
            new_episodes_scrolled.add (new_episodes_listbox);
            this.pack_start (new_episodes_scrolled, true, true, 15);
            this.pack_start (add_all_to_queue_button, false, false, 15);
            new_episodes_listbox.activate_on_single_click = false;
            new_episodes_listbox.row_activated.connect(on_row_activated);

        }

        public void populate_episodes_list () {

            GLib.ListStore elm = new GLib.ListStore ( typeof (Episode) );

            foreach (Episode e in controller.library.get_new_episodes ()) {
                elm.append (e);
            }

            this.episodeListModel = elm;
            new_episodes_listbox.bind_model(this.episodeListModel, (item) => {
                    return  new EpisodeDetailBox( (Episode) item, 0, 0, false, true);
            });

            show_all ();
        }

        public void on_row_activated (Gtk.ListBoxRow row) {
            var index = row.get_index ();
            info("Index: %d".printf(index));
            Episode ep = (Episode) episodeListModel.get_item(index);
            play_episode_requested (ep);
        }
    }
}
