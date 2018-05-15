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
    public class AllPodcastView : Gtk.ScrolledWindow {
        public signal void on_art_activated(CoverArt coverart);

        public Gtk.FlowBox all_flowbox;
        public Gee.ArrayList<CoverArt> all_art;
        private Library library;

        public AllPodcastView(Library library) {
            //  base(null, null);
            this.library = library;

            all_art = new Gee.ArrayList<CoverArt>();

            all_flowbox = new Gtk.FlowBox();
            all_flowbox.get_style_context().add_class("notebook-art");
            all_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            all_flowbox.activate_on_single_click = true;
            all_flowbox.child_activated.connect((child) => {
                CoverArt coverart = all_flowbox.get_child_at_index(child.get_index()).get_child() as CoverArt;
                all_flowbox.unselect_all();

                on_art_activated(coverart);
            });
            all_flowbox.valign = Gtk.Align.FILL;
            all_flowbox.homogeneous = true;
            all_flowbox.row_spacing = 20;

            refresh_art();
            add(all_flowbox);
        }

        public void clear() {
            for(int i = 0; i < all_art.size; i++) {
                all_flowbox.remove(all_flowbox.get_child_at_index(0));
            }

            all_art.clear();
        }

        public void refresh_art() {
            foreach(Podcast podcast in library.podcasts) {
                CoverArt coverart = new CoverArt(podcast.coverart_uri.replace("%27", "'"), podcast, true);
                
                coverart.get_style_context().add_class("coverart");
                coverart.halign = Gtk.Align.START;
                coverart.valign = Gtk.Align.START;
                
                int currently_unplayed = 0;
                foreach(Episode episode in podcast.episodes) {
                    if (episode.status == EpisodeStatus.UNPLAYED) {
                        currently_unplayed++;
                    }
                }

                if(currently_unplayed > 0) {
                    coverart.set_count(currently_unplayed);
                    coverart.show_count();
                } else {
                    coverart.hide_count();
                }

                all_art.add(coverart);
                all_flowbox.add(coverart);
            }
        }

        public void unselect_all() {
            all_flowbox.unselect_all();
        }

        public void mark_all_as_played(Podcast podcast) {
            update_count_for_podcast(podcast, 0);
        }

        public void update_count_for_podcast(Podcast podcast, int count) {
            foreach(CoverArt coverart in all_art) {
                if(coverart.podcast == podcast) {
                    coverart.set_count(count);
                    if(count > 0) {
                        coverart.show_count();
                    } else {
                        coverart.hide_count();
                    }
                }
            }
        }

        public void toggle_coverart_label(bool show_label) {
            foreach(CoverArt coverart in all_art) {
                if(show_label) {
                    coverart.show_name_label();
                } else {
                    coverart.hide_name_label();
                }
            }
        }

        public CoverArt? get_coverart_for_podcast(Podcast podcast) {
            foreach(CoverArt coverart in all_art) {
                if(coverart.podcast.name == podcast.name) {
                    return coverart;
                }
            }

            return null;
        }
    }
}