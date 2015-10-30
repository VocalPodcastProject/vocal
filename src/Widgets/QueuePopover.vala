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

		public QueuePopover(Gtk.Widget parent) {
			this.set_relative_to(parent);
			episodes =  new Gtk.ListBox();
			this.add(episodes);
		}

		public void set_queue(Gee.ArrayList<Episode> queue) {
			this.remove(episodes);
			episodes = new Gtk.ListBox();
			rows = new Gee.ArrayList<QueueRow>();
			if(queue.size > 0) {
				foreach(Episode e in queue) {
					QueueRow q = new QueueRow(e);
					q.move_up.connect((e) => { move_up(e); });
					q.move_down.connect((e) => { move_down(e); });
					q.remove_episode.connect((e) => { remove_episode(e); });
					episodes.add(q);
					rows.add(q);
				}
			} else {
				var label = new Gtk.Label("No episodes in queue");
				label.get_style_context().add_class("h3");
				label.margin  = 12;
				episodes.add(label);
			}
			episodes.row_activated.connect(on_row_activated);
			this.add(episodes);
		}

		public void on_row_activated(Gtk.ListBoxRow row) {
			int index = row.get_index();
			play_episode_from_queue_immediately(rows[index].episode);
		}
  	}
}
