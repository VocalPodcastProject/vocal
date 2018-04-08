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
    
        public signal void play_episode_requested (Episode episode);
        public signal void add_all_new_to_queue (Gee.ArrayList<Episode> episodes);
        public signal void go_back();

        private Controller controller;
        private ListBox new_episodes_listbox;
        private GLib.ListStore episode_model = new GLib.ListStore(typeof(Episode));
        
        public NewEpisodesView (Controller cont) {
            controller = cont;
            this.orientation = Gtk.Orientation.VERTICAL;
            
            var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            toolbar.get_style_context().add_class("toolbar");
            toolbar.get_style_context().add_class("library-toolbar");

            var go_back_button = new Gtk.Button.with_label(_("Your Podcasts"));
            go_back_button.clicked.connect(() => { go_back(); });
            go_back_button.get_style_context().add_class("back-button");
            go_back_button.margin = 6;
            
            toolbar.pack_start(go_back_button, false, false, 0);
            pack_start(toolbar, false, true, 0);
            
            var new_episodes_label = new Gtk.Label (_("New Episodes"));
            new_episodes_label.get_style_context ().add_class ("h2");
            new_episodes_label.margin_top = 12;
            
            new_episodes_listbox = new Gtk.ListBox ();
            new_episodes_listbox.bind_model(episode_model, create_episode_detail_box);
            new_episodes_listbox.margin_left = 50;
            new_episodes_listbox.margin_right = 50;
            new_episodes_listbox.activate_on_single_click = false;
            new_episodes_listbox.row_activated.connect((row) => {
                var activated_episode = episode_model.get_item(row.get_index()) as Episode;
                play_episode_requested (activated_episode);
            });
            
            var add_all_to_queue_button = new Gtk.Button.with_label (_("Add all new episodes to the queue"));
            add_all_to_queue_button.margin_left = 50;
            add_all_to_queue_button.margin_right = 50;
            add_all_to_queue_button.clicked.connect (() => {
                var episodes = new Gee.ArrayList<Episode>();

                for (int i = 0; i < episode_model.get_n_items(); i++) {
                    var episode = episode_model.get_item(i) as Episode;
                    episodes.add(episode);
                }

                add_all_new_to_queue(episodes);
            });
            
            pack_start (new_episodes_label, false, true, 0);
            pack_start (new_episodes_listbox, true, true, 15);
            pack_start (add_all_to_queue_button, false, false, 15);
        }
        
        public void populate_episodes_list () {
            episode_model.remove_all();

            foreach (Podcast p in controller.library.podcasts) {
                foreach (Episode e in p.episodes) {
                    if (e.status == EpisodeStatus.UNPLAYED) {
                        episode_model.append(e);
                    }
                }
            }
        }

        private Widget create_episode_detail_box(Object item) {
            var episode = item as Episode;

            var new_episode = new EpisodeDetailBox (episode, 0, 0, false, true);
            new_episode.margin_top = 12;

            return new_episode;
        }

        public void remove_episode_from_list (Episode episode) {
            for (int i = 0; i < episode_model.get_n_items(); i++) {
                var e = episode_model.get_item(i) as Episode;

                if (episode.title == e.title) {
                    episode_model.remove(i);
                    return;
                }
            }
        }
    }
}
