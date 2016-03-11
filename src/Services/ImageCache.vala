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
n
  END LICENSE

  Additional contributors/authors:

  * Akshay Shekher <voldyman666@gmail.com>

***/

namespace Vocal {

    public class ImageCache : GLib.Object {
        private static DiskCacher cacher;
        private static Gee.HashMap<uint, File> cache;
        private static Soup.Session soup_session;

        static construct {
            // till the cache get initialized
            cache = new Gee.HashMap<uint, File>();

            var settings = VocalSettings.get_default_instance();
            var home_dir = GLib.Environment.get_home_dir();
            var cache_directory =
                "%s/.cache".printf(
                    settings.library_location.replace("~", home_dir)
                );
            soup_session = new Soup.Session();
            cacher = new DiskCacher(cache_directory);
            cacher.get_cached_files.begin((obj, res) => {
                cache = cacher.get_cached_files.end(res);
            });
        }

        public ImageCache() {
        }

        public async Gdk.Pixbuf get_image(string url) {
            uint url_hash = url.hash();
            Gdk.Pixbuf pixbuf;

            if (cache.has_key(url_hash)) {
                pixbuf = yield cacher.get_cached_file(cache.@get(url_hash));

            } else {
                pixbuf = yield load_image_async(url);
                if (pixbuf != null) {
                    var cached_file = yield cacher.cache_file(url_hash, pixbuf);
                    cache.@set(url_hash, cached_file);
                    print("loaded " + url + "\n");
                }
            }

            return pixbuf;
        }

        private async Gdk.Pixbuf load_image_async(string url) {
            Gdk.Pixbuf pixbuf = null;
            Soup.Request req = soup_session.request(url);
            InputStream image_stream = req.send(null);
            pixbuf = yield new Gdk.Pixbuf.from_stream_async(image_stream, null);
            return pixbuf;
        }

        private class DiskCacher {
            private File cache_location;
            private string location;

            public DiskCacher(string location) {
                this.location = location;
                this.cache_location = File.new_for_path(location);
            }

            public async Gee.HashMap<uint, File> get_cached_files() {
                Gee.HashMap<uint, File> files = new Gee.HashMap<uint, File>();
                try {
                    FileEnumerator enumerator = yield
                        cache_location.enumerate_children_async("standard::*",
                                                            FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                            Priority.DEFAULT, null);
                    List<FileInfo> infos;
                    while((infos = yield enumerator.next_files_async(10)) != null) {
                        foreach(var info in infos) {
                            var name = info.get_name();
                            var file = File.new_for_path("%s/%s".printf(location, name));
                            var hashed_name = (uint)uint64.parse(name);
                            files.@set(hashed_name, file);
                        }
                    }
                } catch (Error e) {
                    warning("Could not load cached images");
                }
                return files;
            }

            public async File cache_file(uint hashed_name, Gdk.Pixbuf pixbuf) {
                var file_loc = "%s/%ud".printf(this.location, hashed_name);
                var cfile = File.new_for_path(file_loc);

                var cache_dir = cfile.get_parent();
                if (!cache_dir.query_exists()) {
                    cache_dir.make_directory();
                }

                var fiostream = yield cfile.create_readwrite_async(FileCreateFlags.NONE);
                // switch to async version later, currently the bindings have a bug
                pixbuf.save_to_stream(fiostream.get_output_stream(), "png");

                return cfile;
            }

            public async Gdk.Pixbuf get_cached_file(File file) {
                Gdk.Pixbuf pixbuf = null;
                try {
                    var fiostream = yield file.open_readwrite_async();
                    pixbuf = yield new Gdk.Pixbuf.from_stream_async(fiostream.get_input_stream(), null);
                } catch(Error e) {
                    warning ("Couldn't write to file. " + e.message);
                }
                return pixbuf;
            }
        }
    }
}
