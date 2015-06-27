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

public class VocalSettings : Granite.Services.Settings {

    public bool auto_download { get; set; }
    public bool autoclean_library { get; set; }
    public bool continue_running_after_close { get; set; }
    public bool hide_played { get; set; }
    
    public int update_interval { get; set; }
    public int window_width { get; set; }
    public int window_height { get; set; }
    public int sidebar_width {get; set; }
    public int fast_forward_seconds { get; set; }
    public int rewind_seconds { get; set;}
    
    public string library_location { get; set; }
    public string last_played_media { get; set; }
    
    public VocalSettings() {
        base("net.launchpad.vocal");
    }
}
