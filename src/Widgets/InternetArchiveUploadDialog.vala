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

namespace Vocal {

    public class InternetArchiveUploadDialog : Gtk.Dialog {

        /*
         * Constructor for a settings dialog given the current settings
         * and a parent window the set the dialog relative to
         */
        public InternetArchiveUploadDialog (Gtk.Window parent, Episode episode) {

            title = _ ("Upload to Internet Archive");

            get_header_bar ().get_style_context ().remove_class ("header-bar");

            this.modal = true;
            this.set_transient_for (parent);
            var content_box = get_content_area () as Gtk.Box;
            content_box.homogeneous = false;
            content_box.margin_left = 12;
            content_box.margin_right = 12;

            var notebook = new Gtk.Notebook ();
            notebook.expand = true;
            notebook.show_tabs = false;
            notebook.show_border = false;
            content_box.add (notebook);

            var edit_page = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var confirm_page = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var uploading_page = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            notebook.append_page (edit_page);
            notebook.append_page (confirm_page);
            notebook.append_page (uploading_page);

            var verify_label = new Gtk.Label (
                _ ("Please verify that the information below is correct before continuing.")
            );
            verify_label.wrap = true;
            verify_label.max_width_chars = 50;
            verify_label.get_style_context ().add_class ("h3");
            edit_page.pack_start (verify_label, false, false, 10);

            var episode_title_label = new Gtk.Label (_ ("Episode Title"));
            episode_title_label.get_style_context ().add_class ("h4");
            episode_title_label.halign = Gtk.Align.START;
            var episode_title_entry = new Gtk.Entry ();
            episode_title_entry.text = episode.title;

            var podcast_name_label = new Gtk.Label (_ ("Podcast Name"));
            podcast_name_label.get_style_context ().add_class ("h4");
            podcast_name_label.halign = Gtk.Align.START;
            var podcast_name_entry = new Gtk.Entry ();
            podcast_name_entry.text = episode.parent.name;

            var podcast_description_label = new Gtk.Label (_ ("Podcast Description"));
            podcast_description_label.get_style_context ().add_class ("h4");
            podcast_description_label.halign = Gtk.Align.START;
            var podcast_description_entry = new Gtk.TextView ();
            podcast_description_entry.set_wrap_mode (Gtk.WrapMode.WORD);
            podcast_description_entry.buffer.text = episode.parent.description;

            edit_page.pack_start (episode_title_label, false, false, 5);
            edit_page.pack_start (episode_title_entry, false, false, 0);
            edit_page.pack_start (podcast_name_label, false, false, 5);
            edit_page.pack_start (podcast_name_entry, false, false, 0);
            edit_page.pack_start (podcast_description_label, false, false, 5);
            edit_page.pack_start (podcast_description_entry, false, false, 0);

            var next_button = new Gtk.Button.with_label (_ ("Next…"));
            next_button.halign = Gtk.Align.END;
            next_button.get_style_context ().add_class ("suggested-action");
            edit_page.pack_end (next_button, false, false, 10);
            next_button.clicked.connect (() => {
                notebook.next_page ();
            });

            var warning_label = new Gtk.Label (
                _ ("Legal warning: uploading copyrighted materials to the Internet Archvie is illegal. Please make sure you are uploading a copylefted (Creative Commons) episode that you are legally entitled to redistribute.")  // vala-lint=line-length
            );
            warning_label.wrap = true;
            warning_label.max_width_chars = 50;
            warning_label.get_style_context ().add_class ("h4");

            var upload_button = new Gtk.Button.with_label (_ ("Upload to the Internet Archive"));
            upload_button.get_style_context ().add_class ("suggested-action");

            confirm_page.pack_start (warning_label, false, false, 10);
            confirm_page.pack_end (upload_button, false, false, 10);

            var uploading_message = new Gtk.Label (_ ("Uploading episode…"));
            uploading_message.get_style_context ().add_class ("h2");

            var thanks_message = new Gtk.Label (
                _ ("Thanks for contributing to the Internet Archive and the Podcast Archival Project")
            );
            thanks_message.wrap = true;
            thanks_message.justify = Gtk.Justification.CENTER;
            thanks_message.max_width_chars = 50;
            thanks_message.get_style_context ().add_class ("h3");
            thanks_message.set_no_show_all (true);
            thanks_message.hide ();

            var spinner = new Gtk.Spinner ();
            spinner.active = true;

            var upload_complete_image = new Gtk.Image.from_icon_name ("face-cool-symbolic", Gtk.IconSize.DIALOG);
            upload_complete_image.set_no_show_all (true);
            upload_complete_image.hide ();

            uploading_page.pack_start (uploading_message, false, false, 10);
            uploading_page.pack_start (thanks_message, false, false, 10);
            uploading_page.pack_start (spinner, false, false, 25);
            uploading_page.pack_start (upload_complete_image, false, false, 25);

            var finish = new Gtk.Button.with_label (_ ("Finish"));
            finish.get_style_context ().add_class ("suggested-action");
            finish.halign = Gtk.Align.END;
            uploading_page.pack_end (finish, false, false, 10);
            finish.clicked.connect (() => {
                this.destroy ();
            });
            finish.set_no_show_all (true);
            finish.hide ();

            upload_button.clicked.connect (() => {
                notebook.next_page ();
                var loop = new MainLoop ();

                Utils.upload_to_internet_archive (episode.local_uri, episode_title_entry.text, podcast_name_entry.text, podcast_description_entry.buffer.text, (obj, res) => {  // vala-lint=line-length
                    bool success = Utils.upload_to_internet_archive.end (res);
                    if (success) {
                        spinner.active = false;
                        spinner.set_no_show_all (true);
                        spinner.hide ();

                        upload_complete_image.set_no_show_all (false);
                        upload_complete_image.show ();
                        uploading_message.set_text (_ ("Upload Complete"));

                        thanks_message.set_no_show_all (false);
                        thanks_message.show ();

                        finish.set_no_show_all (false);
                        finish.show ();
                    } else {
                        spinner.active = false;
                        spinner.set_no_show_all (true);
                        spinner.hide ();

                        upload_complete_image.set_no_show_all (false);
                        upload_complete_image.show ();
                        uploading_message.set_text (_ ("Upload Failed"));

                        thanks_message.set_text (
                            _ ("Be sure to check your network connection and API keys, then try again later.")
                        );
                        upload_complete_image.set_from_icon_name ("face-confused-symbolic", Gtk.IconSize.DIALOG);

                        thanks_message.set_no_show_all (false);
                        thanks_message.show ();

                        finish.set_no_show_all (false);
                        finish.show ();
                    }
                    loop.quit ();
                });

                loop.run ();
            });
        }


    }
}
