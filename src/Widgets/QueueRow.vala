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
    public class QueueRow : Gtk.Box {

        public signal void move_up(Episode e);
        public signal void move_down(Episode e);
        public signal void remove_episode(Episode e);

        public Episode episode;

        public QueueRow(Episode episode) {
            this.episode = episode;
            this.orientation = Gtk.Orientation.HORIZONTAL;

            Gtk.Button up_button = new Gtk.Button.from_icon_name("go-up-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            up_button.relief = Gtk.ReliefStyle.NONE;
            up_button.set_tooltip_text(_("Move episode up in queue"));
            Gtk.Button down_button = new Gtk.Button.from_icon_name("go-down-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            down_button.relief = Gtk.ReliefStyle.NONE;
            down_button.set_tooltip_text(_("Move episode down in queue"));

            up_button.clicked.connect(() => { move_up(episode); });
            down_button.clicked.connect(() => { move_down(episode); });

            this.pack_start(up_button, false, false, 0);
            this.pack_start(down_button, false, false, 0);

            try {
                GLib.File cover = GLib.File.new_for_uri(episode.parent.coverart_uri);
                InputStream input_stream = cover.read();
                var pixbuf = new Gdk.Pixbuf.from_stream_at_scale(input_stream, 64, 64, true);
                var image = new Gtk.Image.from_pixbuf(pixbuf);
                image.margin = 0;
                image.expand = false;
                image.get_style_context().add_class("album-artwork");

                this.pack_start(image, false, false, 0);
            } catch (Error e) {}

            Gtk.Label title_label = new Gtk.Label(episode.title.replace("%27", "'"));
            this.pack_start(title_label, true, true, 0);

            Gtk.Button remove_button = new Gtk.Button.from_icon_name("process-stop-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            remove_button.get_style_context().add_class("flat");
            remove_button.set_tooltip_text(_("Remove episode from queue"));

            remove_button.clicked.connect(() => { remove_episode(episode); });

            this.pack_start(remove_button, false, false, 0);
        }
    }
}
