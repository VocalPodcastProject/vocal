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
using Gee;
namespace Vocal {

    public class Shownotes : Gtk.Box {

        public signal void play();
        public signal void enqueue();
        public signal void download();
        public signal void mark_as_new();
        public signal void mark_as_played();
        public signal void remove_download();

        public signal void copy_shareable_link ();
        public signal void send_tweet ();
        public signal void copy_direct_link ();

        public Gtk.Button play_button;
        public Gtk.Button queue_button;
        public Gtk.Button download_button;
        public Gtk.Button share_button;
        public Gtk.Button mark_as_played_button;
        public Gtk.Button mark_as_new_button;
        public Gtk.Button delete_button;
        public Episode episode = null;

        private Gtk.Button shareable_link;
        private Gtk.Button tweet;
        private Gtk.Button link_to_file;

        private Gtk.Label title_label;
        private Gtk.Label date_label;
        private Gtk.Label size_and_duration_label;
        private Gtk.Box controls_box;
        private Gtk.Label shownotes_label;

        public Shownotes () {

            this.orientation = Gtk.Orientation.VERTICAL;

            var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content_box.hexpand = true;
            content_box.vexpand = true;



            shownotes_label = new Gtk.Label ("");
            shownotes_label.halign = Gtk.Align.START;
            shownotes_label.valign = Gtk.Align.START;
            shownotes_label.wrap = true;
            shownotes_label.margin_start = 12;
            shownotes_label.vexpand = true;

            controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            controls_box.get_style_context ().add_class ("toolbar");
            controls_box.get_style_context ().add_class ("podcast-view-toolbar");
            controls_box.height_request = 30;
            controls_box.halign = Gtk.Align.END;

            mark_as_played_button = new Gtk.Button.from_icon_name ("object-select-symbolic");
            mark_as_played_button.has_tooltip = true;
            mark_as_played_button.tooltip_text = _ ("Mark this episode as played");
            mark_as_played_button.clicked.connect( () => { mark_as_played(); });

            mark_as_new_button = new Gtk.Button.from_icon_name ("non-starred-symbolic");
            mark_as_new_button.has_tooltip = true;
            mark_as_new_button.tooltip_text = _ ("Mark this episode as new");
            mark_as_new_button.clicked.connect(() => { mark_as_new(); });

            download_button = new Gtk.Button.from_icon_name ("document-save-symbolic");
            download_button.has_tooltip = true;
            download_button.tooltip_text = _ ("Download episode");
            download_button.clicked.connect(() => {download(); });

            delete_button = new Gtk.Button.from_icon_name("user-trash-symbolic");
            delete_button.has_tooltip = true;
            delete_button.tooltip_text = _("Delete downloaded file");
            delete_button.clicked.connect(() => { remove_download(); });

            share_button = new Gtk.Button.from_icon_name ("emblem-shared-symbolic");
            share_button.has_tooltip = true;
            share_button.tooltip_text = _ ("Share this episode");

            shareable_link = new Gtk.Button.with_label("Copy sharaeble link");
            tweet = new Gtk.Button.with_label("Tweet this episode");
            link_to_file = new Gtk.Button.with_label("Copy episode link");

            shareable_link.get_style_context().remove_class("text-button");

            shareable_link.clicked.connect(() => { copy_shareable_link(); });
            tweet.clicked.connect(() => { send_tweet(); });
            link_to_file.clicked.connect(() => { copy_direct_link(); });

            var share_popover = new Gtk.Popover();
            share_popover.set_parent(share_button);
            var share_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            share_box.append(shareable_link);
            share_box.append(tweet);
            share_box.append(link_to_file);
            share_popover.set_child(share_box);

            share_button.clicked.connect(() => {
                share_popover.popup();
            });

            controls_box.append (mark_as_played_button);
            controls_box.append (mark_as_new_button);
            controls_box.append (download_button);
            controls_box.append (delete_button);
            controls_box.append (share_button);


            var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            separator.height_request = 2;
            Utils.set_margins(separator, 12);

            title_label = new Gtk.Label ("");
            title_label.get_style_context ().add_class ("title-4");
            title_label.margin_top = 20;
            title_label.margin_bottom = 6;
            title_label.margin_start = 12;
            title_label.halign = Gtk.Align.CENTER;

            date_label = new Gtk.Label ("");
            date_label.margin_bottom = 12;
            date_label.margin_start = 12;
            date_label.halign = Gtk.Align.CENTER;

            size_and_duration_label = new Gtk.Label ("");
            size_and_duration_label.halign = Gtk.Align.START;
            controls_box.prepend (size_and_duration_label);

            play_button = new Gtk.Button.with_label ("Play this episode");
            play_button.clicked.connect (() => { play(); });
            queue_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            queue_button.has_tooltip = true;
            queue_button.tooltip_text = _ ("Add this episode to the up next list");
            queue_button.clicked.connect(() => { enqueue(); });

            var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
            button_box.append (play_button);
            button_box.append (queue_button);
            button_box.margin_bottom = 20;
            button_box.margin_start = 12;
            button_box.halign = Gtk.Align.CENTER;

            var summary_label = new Gtk.Label (_ ("<b>Summary</b>"));
            summary_label.use_markup = true;
            summary_label.margin_start = 12;
            summary_label.margin_bottom = 6;
            summary_label.halign = Gtk.Align.START;

            content_box.append (separator);
            content_box.append (title_label);
            content_box.append (date_label);
            content_box.append (button_box);
            content_box.append (summary_label);
            content_box.append (shownotes_label);

            var scrolled = new Gtk.ScrolledWindow();
            scrolled.set_child(content_box);

            this.append (scrolled);
            this.append (controls_box);

            mark_as_new.connect(() => {
                show_mark_as_played_button();
            });

            mark_as_played.connect(() => {
                show_mark_as_new_button();
            });

        }

        public void set_episode(Episode e) {
            episode = e;
            set_title(e.title);
            set_description(e.description);
            check_attributes();
        }

        public void check_attributes () {
            if(episode.current_download_status == DownloadStatus.DOWNLOADED) {
                hide_download_button();
            } else {
                show_download_button();
            }

            if(episode.status == EpisodeStatus.PLAYED) {
                show_mark_as_new_button();
            } else {
                show_mark_as_played_button();
            }

            int64 size = Utils.get_file_size(episode.uri);

            size_and_duration_label.label = "Size: %dMB Duration: %s".printf((int)(size / 1048576), episode.duration);
        }

        public void set_description (string description) {
            this.shownotes_label.label = Utils.html_to_markup (description);
            shownotes_label.use_markup = true;
        }

        public void show_download_button () {
            download_button.show ();
            delete_button.hide();
        }

        public void hide_download_button () {
            download_button.hide ();
            delete_button.show ();
        }

        public void set_title (string title) {
            title_label.set_text (title.replace ("%27", "'"));
        }

        public void set_date (GLib.DateTime date) {
            date_label.set_text (date.format ("%x"));
        }

        public void show_mark_as_new_button () {
            mark_as_played_button.hide ();
            mark_as_new_button.show ();
        }

        public void show_mark_as_played_button () {
            mark_as_played_button.show ();
            mark_as_new_button.hide ();
        }

    }
}
