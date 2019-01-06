namespace Vocal {

    public class PodcastView : Gtk.ScrolledWindow {
        private Controller controller;

        private Gtk.Box container;

        public Gee.ArrayList<CoverArt> all_art;
        public Gtk.FlowBox all_flowbox;

        public PodcastView(Controller controller) {
            this.controller = controller;

            container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            all_art = new Gee.ArrayList<CoverArt>();

            all_flowbox = new Gtk.FlowBox();
            all_flowbox.get_style_context().add_class("notebook-art");
            all_flowbox.selection_mode = Gtk.SelectionMode.SINGLE;
            all_flowbox.activate_on_single_click = true;
            all_flowbox.valign = Gtk.Align.START;
            all_flowbox.homogeneous = true;
            all_flowbox.child_activated.connect((child) => {
                Gtk.FlowBox parent = child.parent as Gtk.FlowBox;

                CoverArt art = parent.get_child_at_index(child.get_index()).get_child() as CoverArt;
                parent.unselect_all();

                controller.window.current_episode_art = art;
                controller.highlighted_podcast = art.podcast;
                controller.window.show_details(art.podcast);
            });

            container.add(all_flowbox);

            add(container);
        }

        public void clear() {
            for(int i = 0; i < all_art.size; i++) {
                all_flowbox.remove(all_flowbox.get_child_at_index(0));
            }

            all_art.clear();
        }

        public void populate() {
            foreach(Podcast podcast in controller.library.podcasts) {
                CoverArt coverart = new CoverArt(podcast.coverart_uri.replace("%27", "'"), podcast, true);
                coverart.get_style_context ().add_class (controller.on_elementary ? "card" : "coverart");
                coverart.halign = Gtk.Align.START;
                
                int currently_unplayed = 0;
                foreach(Episode e in podcast.episodes) {
                    if (e.status == EpisodeStatus.UNPLAYED) {
                        currently_unplayed++;
                    }
                }

                if(currently_unplayed > 0) {
                    coverart.set_count(currently_unplayed);
                    coverart.show_count();
                }

                else {
                    coverart.hide_count();
                }

                all_art.add(coverart);
            }
        }

        public void add_coverart_to_view() {
            foreach(CoverArt coverart in all_art) {
                all_flowbox.add(coverart);
            }

            foreach(Gtk.Widget f in all_flowbox.get_children()) {
                f.halign = Gtk.Align.CENTER;
                f.valign = Gtk.Align.START;
            }
        }

        public void mark_all_as_played(Podcast podcast) {
            foreach(CoverArt coverart in all_art) {
                if(coverart.podcast == podcast) {
                    coverart.set_count(0);
                    coverart.hide_count();
                }
            }
        }

        public void update_count(Podcast podcast, int unplayed_count) {
            foreach(CoverArt coverart in all_art) {
                if(coverart.podcast == podcast) {
                    coverart.set_count(unplayed_count);

                    if(unplayed_count > 0) {
                        info("hide_count error");
                        coverart.show_count();
                        info("hide_count error end");
                    } else {
                        coverart.hide_count();
                    }
                }
            }
        }

        public CoverArt? get_art(Podcast podcast) {
            foreach(CoverArt coverart in all_art) {
                if(coverart.podcast.name == podcast.name) {
                    all_flowbox.unselect_all();

                    return coverart;
                }
            }

            return null;
        }

        /*
         * Called when the user toggles the show name label setting.
         * Calls the show/hide label method for every CoverArt.
         */
        public void on_show_name_label_toggled() {
            foreach(CoverArt coverart in all_art) {
                if(controller.settings.show_name_label) {
                    coverart.show_name_label();
                } else {
                    coverart.hide_name_label();
                }
            }
        }

        public void update_cover_art(Podcast podcast, string path) {
            foreach(CoverArt coverart in all_art) {
                if(coverart.podcast == podcast) {
                    // TODO: This doesn't work. We update the CoverArt in all_art, but we don't update the widget in the flowbox. 
                    // So this change isn't seen until vocal is restarted.
                    try {
                        InputStream input_stream = GLib.File.new_for_path(path).read();
                        coverart.image.pixbuf = CoverArt.create_cover_image(input_stream);
                    } catch(Error e) {
                        error("Failed to load image from path %s. %s", path, e.message);
                    }

                    // Now copy the image to controller.library cache and set it in the db
                    controller.library.set_new_local_album_art(path, podcast);
                    return;
                }
            }
        }
    }
}