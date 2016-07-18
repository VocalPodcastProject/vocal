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

    public class SearchResultsView : Gtk.Box {

        public signal void on_new_subscription(string url);
        public signal void return_to_library(); 

        public signal void episode_selected(Podcast podcast, Episode episode);
        public signal void podcast_selected(Podcast podcast);

        private string search_term = "";

        private Gtk.Label title_label;
        private iTunesProvider itunes;

        private Gtk.ListBox     local_episodes_listbox;
        private Gtk.ListBox     local_podcasts_listbox;
        private Gtk.FlowBox     cloud_results_flowbox;

        private Gee.ArrayList<Widget> local_episodes_widgets;
        private Gee.ArrayList<Widget> local_podcasts_widgets;
        private Gee.ArrayList<Widget> cloud_results_widgets;

        private Gtk.Box content_box;
        private Gtk.Box loading_box;

        private Library library;

        /*
         * Constructor for the full search results view. Shows all matches from the local library and across the iTunes ecosystem
         */
        public SearchResultsView(string query, Library library, Gee.ArrayList<Podcast> p_matches, Gee.ArrayList<Episode> e_matches) {

            this.set_orientation(Gtk.Orientation.VERTICAL);
            this.itunes = new iTunesProvider();
            this.library = library;
            this.search_term = query;

            var return_button = new Gtk.Button.with_label(_("Return to Library"));
            return_button.clicked.connect(() => { return_to_library (); });
            
            return_button.get_style_context().add_class("back-button");
            return_button.margin = 6;
            return_button.expand = false;
            return_button.halign = Gtk.Align.START;

            // Set up the title

            title_label = new Gtk.Label(_("Search Results for <i>%s</i>".printf(search_term)));
            title_label.margin_top = 5;
            title_label.margin_bottom = 5;
            title_label.justify = Gtk.Justification.CENTER;
            title_label.expand = false;
            title_label.use_markup = true;
            Granite.Widgets.Utils.apply_text_style_to_label (Granite.TextStyle.H2, title_label);

            var local_episodes_label = new Gtk.Label(_("Episodes from Your Library"));
            var local_podcasts_label = new Gtk.Label(_("Podcasts from Your Library"));
            var cloud_results_label = new Gtk.Label(_("iTunes Podcast Results"));

            local_episodes_label.get_style_context().add_class("h4");
            local_episodes_label.set_property("xalign", 0);
            local_podcasts_label.get_style_context().add_class("h4");
            local_podcasts_label.set_property("xalign", 0);
            cloud_results_label.get_style_context().add_class("h4");
            cloud_results_label.set_property("xalign", 0);

            var return_button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            return_button_box.get_style_context().add_class("toolbar");
            return_button_box.get_style_context().add_class("library-toolbar");
            return_button_box.add(return_button);
            this.add(return_button_box);
            this.add(title_label);

            // Create the lists container
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            var scrolled = new Gtk.ScrolledWindow(null, null);
            content_box.add(title_label);
            scrolled.add(content_box);
            this.add(scrolled);

            local_episodes_listbox = new Gtk.ListBox();
            local_podcasts_listbox = new Gtk.ListBox();
            cloud_results_flowbox = new Gtk.FlowBox();

            local_episodes_listbox.activate_on_single_click = true;
            local_podcasts_listbox.activate_on_single_click = true;

            local_episodes_listbox.button_press_event.connect(on_episode_activated);
            local_podcasts_listbox.button_press_event.connect(on_podcast_activated);

            local_episodes_widgets = new Gee.ArrayList<Widget>();
            local_podcasts_widgets = new Gee.ArrayList<Widget>();
            cloud_results_widgets = new Gee.ArrayList<Widget>();


            foreach(Podcast p in p_matches) {
                SearchResultBox srb = new SearchResultBox(p, null);
                local_podcasts_widgets.add(srb);
                local_podcasts_listbox.add(srb);
            }

            if(p_matches.size == 0) {
                var empty_p_label = new Gtk.Label(_("No matching podcasts found."));
                empty_p_label.get_style_context().add_class("h3");
                local_podcasts_listbox.add(empty_p_label);
            }

            foreach(Episode e in e_matches) {
                Podcast parent = null;
                foreach(Podcast p in library.podcasts) {
                    if(e.parent.name == p.name) {
                        parent = p;
                    }
                }
                SearchResultBox srb = new SearchResultBox(parent, e);
                local_episodes_widgets.add(srb);
                local_episodes_listbox.add(srb);
            }

            if(e_matches.size == 0) {
                var empty_e_label = new Gtk.Label(_("No matching episodes found."));
                empty_e_label.get_style_context().add_class("h3");
                local_episodes_listbox.add(empty_e_label);
            }
            
            content_box.add(local_podcasts_label);
            content_box.add(local_podcasts_listbox);
            local_podcasts_listbox.expand = true;
            content_box.add(local_episodes_label);
            content_box.add(local_episodes_listbox);
            local_episodes_listbox.expand = true;
            content_box.add(cloud_results_label);
            content_box.add(cloud_results_flowbox);

            content_box.margin = 5;

            loading_box = new  Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            var spinner = new Gtk.Spinner();
            spinner.active = true; 
            var loading_label = new Gtk.Label(_("Loading full iTunes results"));
            loading_box.add(loading_label);
            loading_box.add(spinner);
            content_box.add(loading_box);

            load_from_itunes();

        }

        /*
         * Loads the full list of iTunes store matches (popover limited to top 5 only, for both speed and size concerns)
         */
        private async void load_from_itunes() {

            SourceFunc callback = load_from_itunes.callback;

            ThreadFunc<void*> run = () => {
                Gee.ArrayList<DirectoryEntry> c_matches = itunes.search_by_term(search_term);
                foreach(DirectoryEntry c in c_matches) {
                    DirectoryArt a = new DirectoryArt(c.itunesUrl, c.title, c.artist, c.summary, c.artworkUrl600);
                    a.subscribe_button_clicked.connect((url) => {
                        on_new_subscription(url);
                    });
                    cloud_results_widgets.add(a);
                    
                }

                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);

            yield;

            foreach(Widget w in cloud_results_widgets) {
                cloud_results_flowbox.add(w);
            }
            loading_box.set_no_show_all(true);
            loading_box.hide();
            show_all();

        }

        /*
         * Called when a matching episode is selected by the user
         */
        private bool on_episode_activated(Gdk.EventButton button) {
            var row = local_episodes_listbox.get_row_at_y((int)button.y);
            int index = row.get_index();
            SearchResultBox selected = local_episodes_widgets[index] as SearchResultBox;
            episode_selected(selected.get_podcast(), selected.get_episode());
            return false;
        }

        /*
         * Called when a matching podcast is selected by the user
         */
        private bool on_podcast_activated(Gdk.EventButton button) {
            var row = local_podcasts_listbox.get_row_at_y((int)button.y);
            int index = row.get_index();
            SearchResultBox selected = local_podcasts_widgets[index] as SearchResultBox;
            podcast_selected(selected.get_podcast());
            return false;
        }
    }
}
