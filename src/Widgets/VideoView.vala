namespace Vocal {

	public class VideoView : Gtk.Box {
		public Controller controller;

		public Clutter.Actor actor;
        public GtkClutter.Actor bottom_actor;
        public GtkClutter.Actor return_actor;
        public Clutter.Stage stage;
        public GtkClutter.Embed video_widget;
        public VideoControls video_controls;
        private Gtk.Revealer return_revealer;
        private Gtk.Button return_to_library;

        private uint hiding_timer = 0; // Used for hiding video controls
        private bool mouse_primary_down = false;

		public VideoView(Controller controller) {
			orientation = Gtk.Orientation.VERTICAL;

			this.controller = controller;

			// Create the drawing area for the video widget
            video_widget = new GtkClutter.Embed ();
            video_widget.use_layout_size = false;
            video_widget.button_press_event.connect (on_video_button_press_event);
            video_widget.button_release_event.connect (on_video_button_release_event);

            stage = video_widget.get_stage() as Clutter.Stage;
            stage.background_color = {0, 0, 0, 0};
            stage.use_alpha = true;

            actor = new Clutter.Actor();
            var aspect_ratio = new ClutterGst.Aspectratio ();
            ((ClutterGst.Content) aspect_ratio).player = controller.player;
            actor.content = aspect_ratio;

            actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));
            stage.add_child (actor);

            // Set up all the video controls
            video_controls = new VideoControls ();
            video_controls.vexpand = true;
            video_controls.set_valign (Gtk.Align.END);
            video_controls.unfullscreen.connect (() => {
            	video_controls.set_reveal_child(false);
            	controller.window.on_fullscreen_request();
            });
            video_controls.play_toggled.connect (controller.play_pause);
            video_controls.progress_bar_scale_changed.connect (() => {
                controller.player.set_position (video_controls.progress_bar_fill);
            });

            bottom_actor = new GtkClutter.Actor.with_contents (video_controls);
            stage.add_child (bottom_actor);

            var child1 = video_controls.get_child () as Gtk.Container;
            foreach(Gtk.Widget child in child1.get_children()) {
                child.parent.get_style_context ().add_class ("video-toolbar");
                child.parent.parent.get_style_context ().add_class ("video-toolbar");
            }

            video_widget.motion_notify_event.connect (on_motion_event);

            return_to_library = new Gtk.Button.with_label (_("Return to Library"));
            return_to_library.get_style_context ().add_class ("video-widgets-background");
            return_to_library.has_tooltip = true;
            return_to_library.tooltip_text = _("Return to Library");
            return_to_library.relief = Gtk.ReliefStyle.NONE;
            return_to_library.margin = 5;
            return_to_library.set_no_show_all (false);
            return_to_library.show();
            return_to_library.clicked.connect (() => {
            	controller.window.on_return_to_library();
            });

            return_revealer = new Gtk.Revealer ();
            return_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
            return_revealer.add (return_to_library);

            return_actor = new GtkClutter.Actor.with_contents (return_revealer);
            stage.add_child (return_actor);

            add(video_widget);
		}

		/*
         * Requests the app to be taken fullscreen if the video widget
         * is double-clicked
         */
        private bool on_video_button_press_event(Gdk.EventButton e) {
            mouse_primary_down = true;
            if(e.type == Gdk.EventType.2BUTTON_PRESS) {
                controller.window.on_fullscreen_request();
            }

            return false;
        }

        private bool on_video_button_release_event(Gdk.EventButton e) {
            mouse_primary_down = false;
            return false;
        }

        /*
		 * Called when the user moves the cursor when a video is playing
		 */
        private bool on_motion_event(Gdk.EventMotion e) {
            // Figure out if you should just move the window
            if (mouse_primary_down) {
                mouse_primary_down = false;
                controller.window.begin_move_drag (Gdk.BUTTON_PRIMARY, (int)e.x_root, (int)e.y_root, e.time);
            } else {

                // Show the cursor again
                controller.window.get_window ().set_cursor (null);

                bool hovering_over_headerbar = false,
                hovering_over_return_button = false,
                hovering_over_video_controls = false;

                int min_height, natural_height;
                video_controls.get_preferred_height(out min_height, out natural_height);


                // Figure out whether or not the cursor is over the video bar at the bottom
                // If so, don't actually hide the cursor
                if (controller.window.fullscreened && e.y < natural_height) {
                    hovering_over_video_controls = true;
                } else {
                    hovering_over_video_controls = false;
                }


                // e.y starts at 0.0 (top) and goes for however long
                // If < 10.0, we can assume it's above the top of the video area, and therefore
                // in the headerbar area
                if (!controller.window.fullscreened && e.y < 10.0) {
                    hovering_over_headerbar = true;
                }


                if (hiding_timer != 0) {
                    Source.remove (hiding_timer);
                }

                if(controller.window.current_widget == controller.window.video_view) {

                    hiding_timer = GLib.Timeout.add (2000, () => {

                        if(controller.window.current_widget != controller.window.video_view) {
                            this.get_window ().set_cursor (null);
                            return false;
                        }

                        if(!controller.window.fullscreened && (hovering_over_video_controls || hovering_over_return_button)) {
                            hiding_timer = 0;
                            return true;
                        }

                        else if (hovering_over_video_controls || hovering_over_return_button) {
                            hiding_timer = 0;
                            return true;
                        }

                        video_controls.set_reveal_child(false);
                        return_revealer.set_reveal_child(false);

                        if(controller.player.playing && !hovering_over_headerbar) {
                            this.get_window ().set_cursor (new Gdk.Cursor (Gdk.CursorType.BLANK_CURSOR));
                        }

                        return false;
                    });


                    if(controller.window.fullscreened) {
                        bottom_actor.width = stage.width;
                        bottom_actor.y = stage.height - natural_height;
                        video_controls.set_reveal_child(true);
                    }
                    return_revealer.set_reveal_child(true);

                }
            }

            return false;
        }
	}
}