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

    public class SearchResultsView : Gtk.Box {

        public signal void on_new_subscription (string url);

        public signal void episode_selected (Podcast podcast, Episode episode);
        public signal void podcast_selected (Podcast podcast);

        public Gtk.SearchEntry search_entry;

        private string search_term = "";

        private Gtk.Label title_label;
        private iTunesProvider itunes;

        private Gtk.ListBox local_episodes_listbox;
        private Gtk.ListBox local_podcasts_listbox;
        private Gtk.FlowBox cloud_results_flowbox;

        private Gee.ArrayList<Widget> local_episodes_widgets;
        private Gee.ArrayList<Widget> local_podcasts_widgets;
        private Gee.ArrayList<Widget> cloud_results_widgets;

        private Gtk.Box content_box;
        private Gtk.Spinner spinner;

        private Library library;

        private Gtk.Label no_local_episodes_label;
        private Gtk.Label no_local_podcasts_label;

        private Gtk.Revealer local_podcasts_revealer;
        private Gtk.Revealer local_episodes_revealer;
        private Gtk.Revealer cloud_results_revealer;

        /*
         * Constructor for the full search results view.
         * Shows all matches from the local library and across the iTunes ecosystem.
         */
        public SearchResultsView (Library library) {

            this.set_orientation (Gtk.Orientation.VERTICAL);
            this.itunes = new iTunesProvider ();
            this.library = library;

            // Set up the title
            title_label = new Gtk.Label ("");
            title_label.margin_top = 12;
            title_label.margin_bottom = 12;
            title_label.justify = Gtk.Justification.CENTER;
            title_label.hexpand = false;
            title_label.use_markup = true;
            title_label.get_style_context ().add_class ("h2");

            var local_episodes_label = new Gtk.Label (_ ("Episodes from Your Library"));
            var local_podcasts_label = new Gtk.Label (_ ("Podcasts from Your Library"));
            var cloud_results_label = new Gtk.Label (_ ("iTunes Podcast Results"));

            local_episodes_label.margin_end = 12;
            local_episodes_label.margin_start = 12;
            local_podcasts_label.margin_end = 12;
            local_podcasts_label.margin_start = 12;

            local_episodes_label.get_style_context ().add_class ("title-3");
            local_episodes_label.set_property ("xalign", 0);
            local_podcasts_label.get_style_context ().add_class ("title-3");
            local_podcasts_label.set_property ("xalign", 0);
            cloud_results_label.get_style_context ().add_class ("title-3");
            cloud_results_label.set_property ("xalign", 0);

            var iTunes_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
            spinner = new Gtk.Spinner ();

            search_entry = new Gtk.SearchEntry ();
            search_entry.valign = Gtk.Align.CENTER;
            search_entry.halign = Gtk.Align.CENTER;
            search_entry.margin_top  = 6;
            search_entry.margin_bottom = 6;
            search_entry.activate.connect (() => {
                this.search_term = search_entry.text;
                title_label.label = _ ("Search Results for <i>%s</i>".printf (search_term));
                reset ();
                show_spinner ();
                load_from_itunes.begin ((obj, res) => {
                    load_from_itunes.end(res);
                });
                load_local_results.begin ((obj, res) => {
                    load_local_results.end(res);
                });
            });

            this.append (search_entry);

            // Create the lists container
            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.vexpand = true;
            content_box.append (title_label);
            scrolled.set_child (content_box);
            this.append (scrolled);

            local_episodes_listbox = new Gtk.ListBox ();
            local_podcasts_listbox = new Gtk.ListBox ();
            cloud_results_flowbox = new Gtk.FlowBox ();

            local_episodes_listbox.activate_on_single_click = true;
            local_podcasts_listbox.activate_on_single_click = true;
            local_episodes_listbox.get_style_context().add_class ("boxed-list");
            local_podcasts_listbox.get_style_context().add_class ("boxed-list");
            Utils.set_margins(local_episodes_listbox, 12);
            Utils.set_margins(local_podcasts_listbox, 12);

            //local_episodes_listbox.button_press_event.connect (on_episode_activated);
            //local_podcasts_listbox.button_press_event.connect (on_podcast_activated);
            local_episodes_listbox.hexpand = true;
            local_podcasts_listbox.hexpand = true;
            cloud_results_flowbox.hexpand = true;

            local_episodes_widgets = new Gee.ArrayList<Gtk.Widget> ();
            local_podcasts_widgets = new Gee.ArrayList<Gtk.Widget> ();
            cloud_results_widgets = new Gee.ArrayList<Gtk.Widget> ();

            no_local_episodes_label = new Gtk.Label (_ ("No matching episodes found in your library."));
            no_local_podcasts_label = new Gtk.Label (_ ("No matching podcasts found in your library."));
            no_local_episodes_label.halign = Gtk.Align.CENTER;
            no_local_podcasts_label.halign = Gtk.Align.CENTER;
            no_local_episodes_label.get_style_context ().add_class ("title-3");
            no_local_podcasts_label.get_style_context ().add_class ("title-3");


            local_podcasts_revealer = new Gtk.Revealer ();
            local_episodes_revealer = new Gtk.Revealer ();
            cloud_results_revealer = new Gtk.Revealer ();

            var local_podcasts_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            local_podcasts_container.margin_start = 12;
            local_podcasts_container.margin_end = 12;
            local_podcasts_container.append (local_podcasts_label);
            local_podcasts_container.append (no_local_podcasts_label);
            local_podcasts_container.append (local_podcasts_listbox);
            local_podcasts_revealer.set_child (local_podcasts_container);

            var local_episodes_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            local_episodes_container.margin_start = 12;
            local_episodes_container.margin_end = 12;
            local_episodes_container.append (local_episodes_label);
            local_episodes_container.append (no_local_episodes_label);
            local_episodes_container.append (local_episodes_listbox);
            local_episodes_revealer.set_child (local_episodes_container);

            var cloud_results_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            cloud_results_container.margin_start = 12;
            cloud_results_container.margin_end = 12;
            cloud_results_container.append (cloud_results_label);
            cloud_results_container.append (iTunes_box);
            cloud_results_container.append (cloud_results_flowbox);
            cloud_results_revealer.set_child (cloud_results_container);

            var cloud_title_spinner_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            cloud_title_spinner_box.margin_start = 12;
            cloud_title_spinner_box.margin_end = 12;
            cloud_title_spinner_box.append (cloud_results_label);
            cloud_title_spinner_box.append (spinner);

            content_box.append (local_podcasts_revealer);
            content_box.append (local_episodes_revealer);
            content_box.append (cloud_results_revealer);

            hide_no_local_podcasts ();
            hide_no_local_episodes ();
        }

        private void reset () {
            local_episodes_widgets.clear ();
            local_podcasts_widgets.clear ();
            cloud_results_widgets.clear ();

            local_episodes_listbox.select_all();
            local_podcasts_listbox.select_all();
            cloud_results_flowbox.select_all();
            foreach (Gtk.Widget a in local_episodes_listbox.get_selected_rows ()) {
                local_episodes_listbox.remove (a);
            }
            foreach (Gtk.Widget b in local_podcasts_listbox.get_selected_rows ()) {
                local_podcasts_listbox.remove (b);
            }
            foreach (Gtk.Widget c in cloud_results_flowbox.get_selected_children ()) {
                cloud_results_flowbox.remove (c);
            }
            local_podcasts_revealer.reveal_child = false;
            local_episodes_revealer.reveal_child = false;
            cloud_results_revealer.reveal_child = false;
        }

        /*
         * Loads the full list of iTunes store matches (popover limited to top 5 only, for both speed and size concerns)
         */
        private async void load_from_itunes () {

            GLib.Idle.add(load_from_itunes.callback);
            show_spinner ();

            Gee.ArrayList<DirectoryEntry> c_matches = itunes.search_by_term (search_term);
            foreach (DirectoryEntry c in c_matches) {
                DirectoryArt a = new DirectoryArt (c.itunesUrl, c.title, c.artist, c.summary, c.artworkUrl600);
                a.subscribe_button_clicked.connect ((url) => {
                    on_new_subscription (url);
                });
                cloud_results_widgets.add (a);
            }

            yield;

            foreach (Widget w in cloud_results_widgets) {
                cloud_results_flowbox.append (w);
            }

            if (cloud_results_widgets.size < 1) {
                cloud_results_revealer.reveal_child = false;
            } else {
                cloud_results_revealer.reveal_child = true;
            }

            hide_spinner ();

        }

        /*
         * Loads episode and podcast results from the local library
         */
        private async void load_local_results () {

            GLib.Idle.add(load_local_results.callback);
            Gee.ArrayList<Podcast> p_matches = new Gee.ArrayList<Podcast> ();
            Gee.ArrayList<Episode> e_matches = new Gee.ArrayList<Episode> ();

            if (search_term.length > 0) {

                p_matches.clear ();
                p_matches.add_all (library.find_matching_podcasts (search_term));

                e_matches.clear ();
                e_matches.add_all (library.find_matching_episodes (search_term));
            }

            yield;

            // Actually load and show the results
            foreach (Podcast p in p_matches) {
                SearchResultBox srb = new SearchResultBox (p, null);
                local_podcasts_widgets.add (srb);
                local_podcasts_listbox.append (srb);
            }

            if (p_matches.size == 0) {
                show_no_local_podcasts ();
                hide_local_podcasts_listbox ();

            } else {
                hide_no_local_podcasts ();
                show_local_podcasts_listbox ();
            }

            foreach (Episode e in e_matches) {
                Podcast parent = null;
                foreach (Podcast p in library.podcasts) {
                    if (e.podcast_uri == p.feed_uri) {
                        parent = p;
                    }
                }

                if (parent != null) {
                    SearchResultBox srb = new SearchResultBox (parent, e);
                    local_episodes_widgets.add (srb);
                    local_episodes_listbox.append (srb);
                }
            }

            if (e_matches.size == 0) {
                show_no_local_episodes ();
                hide_local_episodes_listbox ();
            } else {
                hide_no_local_episodes ();
                show_local_episodes_listbox ();
            }
            local_podcasts_revealer.reveal_child = true;
            local_episodes_revealer.reveal_child = true;
        }

        /*
         * Called when a matching episode is selected by the user
         */
        private bool on_episode_activated () {
            /*
            var row = local_episodes_listbox.get_row_at_y ((int)button.y);
            int index = row.get_index ();
            SearchResultBox selected = local_episodes_widgets[index] as SearchResultBox;
            episode_selected (selected.get_podcast (), selected.get_episode ());
            */
            return false;
        }

        /*
         * Called when a matching podcast is selected by the user
         */
        private bool on_podcast_activated () {
            /*
            var row = local_podcasts_listbox.get_row_at_y ((int)button.y);
            int index = row.get_index ();
            SearchResultBox selected = local_podcasts_widgets[index] as SearchResultBox;
            podcast_selected (selected.get_podcast ());
            */
            return false;
        }

        private void hide_spinner () {
            spinner.stop();
            spinner.hide ();
        }

        private void show_spinner () {
            warning("Show spinner");
            spinner.start();
            spinner.show ();
        }

        private void show_no_local_episodes () {
            no_local_episodes_label.show ();
        }

        private void hide_no_local_episodes () {
            no_local_episodes_label.hide ();
        }

        private void show_no_local_podcasts () {
            no_local_podcasts_label.show ();
        }

        private void hide_no_local_podcasts () {
            no_local_podcasts_label.hide ();
        }

        private void hide_local_episodes_listbox () {
            local_episodes_listbox.hide ();
        }

        private void show_local_episodes_listbox () {
            local_episodes_listbox.show ();
        }

        private void hide_local_podcasts_listbox () {
            local_podcasts_listbox.hide ();
        }

        private void show_local_podcasts_listbox () {
            local_podcasts_listbox.show ();
        }
    }
}
