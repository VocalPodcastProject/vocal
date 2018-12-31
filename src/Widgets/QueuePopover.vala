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
		public signal void update_queue(int oldPos, int newPos);
		public signal void move_up(Episode e);
		public signal void move_down(Episode e);
		public signal void remove_episode(Episode e);
		public signal void play_episode_from_queue_immediately(Episode e);

		private QueueList episodes;

		private Gtk.Label label;
		private Gtk.ScrolledWindow scrolled_window;
		private Gtk.Box scrolled_box;

		public QueuePopover(Gtk.Widget parent) {
			this.set_relative_to(parent);

			label = new Gtk.Label(_("No episodes in queue"));
			label.get_style_context().add_class("h3");
			label.margin  = 12;

			scrolled_window = new Gtk.ScrolledWindow(null, null);
			scrolled_window.set_size_request(400, 50);

			scrolled_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
			scrolled_window.add(scrolled_box);

			scrolled_box.add(label);

			this.add(scrolled_window);
		}

		/*
		 * Sets the current queue
		 */
		public void set_queue(Gee.ArrayList<Episode> queue) {

			if (episodes != null) {
				scrolled_box.remove(episodes);
			}

			if(queue.size > 0) {
				hide_label();

				episodes = new QueueList(queue);
				episodes.vadjustment = scrolled_window.vadjustment;
				episodes.update_queue.connect((oldPos, newPos) => { update_queue(oldPos, newPos); });
				episodes.row_activated.connect(on_row_activated);
				episodes.remove_episode.connect((e) => { remove_episode(e); });
				scrolled_box.add(episodes);

			} else {
				show_label();
			}
		}


		/*
		 * Show the "no episodes in queue" label
		 */
		private void show_label() {
			label.set_no_show_all(false);
			label.show();
			scrolled_window.set_size_request(400, 60);
		}


		/*
		 * Hide the "no episodes in queue" label
		 */
		private void hide_label() {
			label.set_no_show_all(true);
			label.hide();
			scrolled_window.set_size_request(400, 225);
		}


		/*
		 * Called whenever the row is activated (when the user clicks it)
		 */
		public void on_row_activated(Gtk.ListBoxRow row) {
			QueueListRow q = (QueueListRow) row;

			play_episode_from_queue_immediately(q.episode);
		}
  }

	class QueueList : Gtk.ListBox {
		public signal void update_queue(int oldPos, int newPos);
		public signal void remove_episode(Episode e);

		public Gee.ArrayList<QueueListRow> rows; 

		private const Gtk.TargetEntry targetEntries[] = {
		  { "GTK_LIST_BOX_ROW", Gtk.TargetFlags.SAME_APP, 0 }
    };

		public QueueList(Gee.ArrayList<Episode> queue) {
			selection_mode = Gtk.SelectionMode.NONE;
			rows = new Gee.ArrayList<QueueListRow>();

			Gtk.drag_dest_set(this, Gtk.DestDefaults.ALL, targetEntries, Gdk.DragAction.MOVE);
      		drag_data_received.connect(on_drag_data_received);

			foreach(Episode e in queue) {
				QueueListRow listRow = new QueueListRow(e);

				listRow.remove_episode.connect((e) => { remove_episode(e); });

				listRow.update_queue.connect((oldPos, newPos) => { update_queue(oldPos, newPos); });

				add(listRow);
				rows.add(listRow);
			}
		}

		private bool scroll_up = false;
		private bool scrolling = false;
    private bool should_scroll = false;
    public Gtk.Adjustment vadjustment;

    private const int SCROLL_STEP_SIZE = 10;
    private const int SCROLL_DISTANCE = 30;
    private const int SCROLL_DELAY = 50;

		public override bool drag_motion(Gdk.DragContext context, int x, int y, uint time) {
			check_scroll (y);
			if(should_scroll && !scrolling) {
				scrolling = true;
				Timeout.add (SCROLL_DELAY, scroll);
			}

			return true;
		}

		private void check_scroll (int y) {
			if (vadjustment == null) {
				return;
			}

			double vadjustment_min = vadjustment.value;
			double vadjustment_max = vadjustment.page_size + vadjustment_min;
			double show_min = double.max(0, y - SCROLL_DISTANCE);
			double show_max = double.min(vadjustment.upper, y + SCROLL_DISTANCE);

			if(vadjustment_min > show_min) {
				should_scroll = true;
				scroll_up = true;
			} else if (vadjustment_max < show_max){
				should_scroll = true;
				scroll_up = false;
			} else {
				should_scroll = false;
			}
		}

    private bool scroll () {
      if (should_scroll) {
        if(scroll_up) {
          vadjustment.value -= SCROLL_STEP_SIZE;
        } else {
          vadjustment.value += SCROLL_STEP_SIZE;
        }
      } else {
        scrolling = false;
      }

      return should_scroll;
    }

    private void on_drag_data_received(Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint target_type, uint time) {
      QueueListRow target;
      Gtk.Widget row;
      QueueListRow source;
      int newPos;
      int oldPos;

      target  = (QueueListRow) get_row_at_y(y);

      newPos = target.get_index();
      row = ((Gtk.Widget[]) selection_data.get_data())[0];
      source = (QueueListRow) row.get_ancestor(typeof(QueueListRow));
      oldPos = source.get_index();

      if(source == target) {
        return;
      }

      remove(source);
      insert(source, newPos);
      update_queue(oldPos, newPos);
    }
	}
}
