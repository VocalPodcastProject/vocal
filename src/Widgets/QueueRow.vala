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

    public class QueueListRow : Gtk.ListBoxRow {
        private const Gtk.TargetEntry targetEntries[] = {  // vala-lint=naming-convention
           { "GTK_LIST_BOX_ROW", Gtk.TargetFlags.SAME_APP, 0 }
        };

        public signal void update_queue (int oldPos, int newPos);  // vala-lint=naming-convention
        public signal void move_up (Episode e);
        public signal void move_down (Episode e);
        public signal void remove_episode (Episode e);

        public Episode episode;
        public Gtk.Box box;

        public QueueListRow (Episode episode) {
            this.episode = episode;

            box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.margin_start = 10;
            box.margin_end = 10;
            this.add (box);

            var handle = new Gtk.EventBox ();
            var dnd_icon = new Gtk.Image.from_icon_name ("view-list-symbolic", Gtk.IconSize.BUTTON);
            handle.add (dnd_icon);
            box.pack_start (handle, false, false, 0);

            Gtk.drag_source_set (handle, Gdk.ModifierType.BUTTON1_MASK, targetEntries, Gdk.DragAction.MOVE);
            handle.drag_begin.connect (on_drag_begin);
            handle.drag_data_get.connect (on_drag_data_get);

            try {
                // Load the actual cover art
                var file = GLib.File.new_for_uri (episode.parent.coverart_uri);
                var icon = new GLib.FileIcon (file);
                var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DIALOG);
                image.pixel_size = 64;
                image.margin = 0;
                image.expand = false;
                image.get_style_context ().add_class ("album-artwork");

                box.pack_start (image, false, false, 0);
            } catch (Error e) {}

            Gtk.Label title_label = new Gtk.Label (
                Utils.truncate_string (
                    episode.title.replace ("%27", "'"),
                    35
                ) + "..."  // vala-lint=ellipsis
            );
            box.pack_start (title_label, false, false, 0);

            Gtk.Button remove_button = new Gtk.Button.from_icon_name (
                "process-stop-symbolic",
                Gtk.IconSize.SMALL_TOOLBAR
            );
            remove_button.get_style_context ().add_class ("flat");
            remove_button.set_tooltip_text (_ ("Remove episode from queue"));

            remove_button.clicked.connect (() => { remove_episode (episode); });

            box.pack_end (remove_button, false, false, 0);
        }

        private void on_drag_begin (Gtk.Widget widget, Gdk.DragContext context) {
          var row = (QueueListRow) widget.get_ancestor (typeof (QueueListRow));

          Gtk.Allocation alloc;
          row.get_allocation (out alloc);

          var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
          var cr = new Cairo.Context (surface);

          row.get_style_context ().add_class ("drag-icon");
          row.draw (cr);
          row.get_style_context ().remove_class ("drag-icon");

          int x, y;
          widget.translate_coordinates (row, 0, 0, out x, out y);
          surface.set_device_offset (-x, -y);
          Gtk.drag_set_icon_surface (context, surface);
        }

        private void on_drag_data_get (
            Gtk.Widget widget,
            Gdk.DragContext context,
            Gtk.SelectionData selection_data,
            uint target_type,
            uint time
        ) {
            uchar[] data = new uchar[(sizeof (QueueListRow))];
            ((Gtk.Widget[])data)[0] = widget;

            selection_data.set (
                Gdk.Atom.intern_static_string ("GTK_LIST_BOX_ROW"), 32, data
            );
        }
    }
}
