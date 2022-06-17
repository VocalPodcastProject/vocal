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


namespace Vocal {

    public class WelcomeScreen : Gtk.Box {

        public signal void add_feed();
        public signal void import();
        public signal void directory();
        public signal void search();
        public signal void sync();

        public WelcomeScreen() {

            this.orientation = Gtk.Orientation.VERTICAL;

            var welcome_label = new Gtk.Label("Welcome to Vocal");
            welcome_label.get_style_context().add_class ("title-1");
            Utils.set_margins(welcome_label, 24);
            welcome_label.margin_top = 24;

            var subtitle_label = new Gtk.Label("Select an option below to get started.");
            subtitle_label.get_style_context().add_class("title-2");
            append(welcome_label);
            append(subtitle_label);


            var choices_list = new Gtk.ListBox();
            Utils.set_margins(choices_list, 50);
            choices_list.get_style_context().add_class("boxed-list");
            choices_list.selection_mode = Gtk.SelectionMode.SINGLE;

            /*
             * Four choices:
             *
             * 1) Add podcast feed
             * 2) Import from OPML file
             * 3) Browse the podcast directory
             * 4) Search the podcast directory
             * 5) Sync with gpodder.net
             *
             */


            var add_feed_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 24);
            var add_feed_icon = new Gtk.Image.from_icon_name ("list-add-symbolic");
            add_feed_icon.pixel_size = 48;
            var add_feed_title = new Gtk.Label("Add podcast feed");
            add_feed_title.halign = Gtk.Align.START;
            add_feed_title.get_style_context().add_class("title-4");
            var add_feed_description = new Gtk.Label("Add a podcast feed with a copied link.");
            add_feed_description.get_style_context().add_class("title-5");
            add_feed_description.halign = Gtk.Align.START;
            var add_feed_text_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            add_feed_text_box.append(add_feed_title);
            add_feed_text_box.append(add_feed_description);
            add_feed_box.append(add_feed_icon);
            add_feed_box.append(add_feed_text_box);
            Utils.set_margins(add_feed_box, 24);


            var import_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 24);
            var import_icon = new Gtk.Image.from_icon_name ("application-rss+xml-symbolic");
            import_icon.pixel_size = 48;
            var import_title = new Gtk.Label("Import from OPML file");
            import_title.get_style_context().add_class("title-4");
            import_title.halign = Gtk.Align.START;
            var import_description = new Gtk.Label("Select a file exported from another podcast app.");
            import_description.get_style_context().add_class("title-5");
            import_description.halign = Gtk.Align.START;
            var import_text_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            import_text_box.append(import_title);
            import_text_box.append(import_description);
            import_box.append(import_icon);
            import_box.append(import_text_box);
            Utils.set_margins(import_box, 24);


            var directory_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 24);
            var directory_icon = new Gtk.Image.from_icon_name("folder-new-symbolic");
            directory_icon.pixel_size = 48;
            var directory_title = new Gtk.Label("Browse the podcast directory");
            directory_title.get_style_context().add_class("title-4");
            directory_title.halign = Gtk.Align.START;
            var directory_description = new Gtk.Label("Browse the most popular podcasts.");
            directory_description.get_style_context().add_class("title-5");
            directory_description.halign = Gtk.Align.START;
            var directory_text_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            directory_text_box.append(directory_title);
            directory_text_box.append(directory_description);
            directory_box.append(directory_icon);
            directory_box.append(directory_text_box);
            Utils.set_margins(directory_box, 24);


            var search_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 24);
            var search_icon = new Gtk.Image.from_icon_name("system-search-symbolic");
            search_icon.pixel_size = 48;
            var search_title = new Gtk.Label("Search the podcast directory");
            search_title.get_style_context().add_class("title-4");
            search_title.halign = Gtk.Align.START;
            var search_description = new Gtk.Label("Find a podcast by searching for a name or a keyword.");
            search_description.get_style_context().add_class("title-5");
            search_description.halign = Gtk.Align.START;
            var search_text_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            search_text_box.append(search_title);
            search_text_box.append(search_description);
            search_box.append(search_icon);
            search_box.append(search_text_box);
            Utils.set_margins(search_box, 24);

            var sync_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 24);
            var sync_icon = new Gtk.Image.from_icon_name("weather-overcast-symbolic");
            sync_icon.pixel_size = 48;
            var sync_title = new Gtk.Label("Sync with gpodder.net");
            sync_title.get_style_context().add_class("title-4");
            sync_title.halign = Gtk.Align.START;
            var sync_description = new Gtk.Label("Sync your subscriptions from gpodder.net.");
            sync_description.get_style_context().add_class("title-5");
            sync_description.halign = Gtk.Align.START;
            var sync_text_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            sync_text_box.append(sync_title);
            sync_text_box.append(sync_description);
            sync_box.append(sync_icon);
            sync_box.append(sync_text_box);
            Utils.set_margins(sync_box, 24);

            choices_list.append(add_feed_box);
            choices_list.append(import_box);
            choices_list.append(directory_box);
            choices_list.append(search_box);
            choices_list.append(sync_box);

            choices_list.row_selected.connect((row) => {
                if (row.child == add_feed_box) {
                    add_feed();
                } else if (row.child == import_box) {
                    import();
                } else if (row.child == directory_box) {
                    directory();
                } else if (row.child == search_box) {
                    search();
                } else {
                    sync();
                }
            });

            append(choices_list);
        }

    }
}
