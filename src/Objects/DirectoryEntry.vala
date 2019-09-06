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

    public class DirectoryEntry {

        public string artist = "";
        public string artworkUrl55 = "";  // vala-lint=naming-convention
        public string artworkUrl60 = "";  // vala-lint=naming-convention
        public string artworkUrl170 = "";  // vala-lint=naming-convention
        public string artworkUrl600 = "";  // vala-lint=naming-convention
        public string itunesUrl = "";  // vala-lint=naming-convention
        public string feedUrl = "";  // vala-lint=naming-convention
        public string summary = "";
        public string title = "";

        public DirectoryEntry () {}
    }
}
