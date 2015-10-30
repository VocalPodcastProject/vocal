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
	public class QueuePopover : Gtk.Popover {

		public signal void move_up(Episode e);
		public signal void move_down(Episode e);
		public signal void remove_episode(Episode e);
		public signal void play_episode_from_queue_immediately(Episode e);

		private Gtk.ListBox episodes;
		private Gee.ArrayList<QueueRow> rows;
		private Gtk.Label label;
		private Gtk.ScrolledWindow scrolled_window;
		private Gtk.Box scrolled_box;

		public QueuePopover(Gtk.Widget parent) {
			this.set_relative_to(parent);

			label = new Gtk.Label("No episodes in queue");
			label.get_style_context().add_class("h3");
			label.margin  = 12;

			episodes =  new Gtk.ListBox();

			scrolled_window = new Gtk.ScrolledWindow(null, null);
			scrolled_window.set_size_request(400, 50);

			scrolled_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
			scrolled_window.add(scrolled_box);

			scrolled_box.add(label);
			scrolled_box.add(episodes);

			this.add(scrolled_window);

		}

		public void set_queue(Gee.ArrayList<Episode> queue) {
			scrolled_box.remove(episodes);
			episodes = new Gtk.ListBox();
			episodes.selection_mode = Gtk.SelectionMode.NONE;
			rows = new Gee.ArrayList<QueueRow>();
			if(queue.size > 0) {

				hide_label();

				foreach(Episode e in queue) {
					QueueRow q = new QueueRow(e);
					q.move_up.connect((e) => { move_up(e); });
					q.move_down.connect((e) => { move_down(e); });
					q.remove_episode.connect((e) => { remove_episode(e); });
					
					episodes.add(q);
					rows.add(q);
				}

				episodes.row_activated.connect(on_row_activated);

				episodes.button_press_event.connect((e) => {
					episodes.row_activated(episodes.get_row_at_y((int)e.y));
					return false;
				});	

			} else {
				show_label();
			}

			scrolled_box.add(episodes);
		}

		private void show_label() {
			label.set_no_show_all(false);
			label.show();
			scrolled_window.set_size_request(400, 60);
		}

		private void hide_label() {
			label.set_no_show_all(true);
			label.hide();
			scrolled_window.set_size_request(400, 225);
		}

		public void on_row_activated(Gtk.ListBoxRow row) {
			int index = row.get_index();
			play_episode_from_queue_immediately(rows[index].episode);
		}
  	}
}
