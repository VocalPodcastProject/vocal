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

using Gtk;

namespace Vocal {
    
    public class DonateDialog : Gtk.Dialog {

        public DonateDialog(Window parent) {
            set_default_response(Gtk.ResponseType.OK);
            set_size_request(720, 480);
            set_modal(true);
            set_transient_for(parent);
            set_attached_to(parent);
            set_resizable(false);
            setup();
            get_action_area().margin = 12;
            this.title = _("Donate to Vocal");

        }

        /*
         * Sets up the properties of the dialog
         */
        private void setup() {

            var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
            content_box.margin_right = 12;
            content_box.margin_left = 12;
          
            var address_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
            var coinbase_view = new WebKit.WebView ();
            coinbase_view.load_uri("https://coinbase.com/nathandyer");

            var paypal_view = new WebKit.WebView ();
            string paypal_html = "<a href=`https://www.paypal.com/cgi-bin/webscr?cmd=_donations&amp;business=ACPGM3FQG589S&amp;lc=US&amp;currency_code=USD&amp;bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHosted`><img class=`aligncenter src=`https://www.paypal.com/en_US/i/btn/btn_donateCC_LG.gif` alt=`Donate Button with Credit Cards` width=`147` height=`47` /></a></center>".replace("`", "\"");
            paypal_view.load_html(paypal_html, "");
            
            var stack = new Gtk.Stack();
            stack.add_named(address_box, "Bitcoin Address");
            stack.add_named(coinbase_view, "Coinbase");
            stack.add_named(paypal_view, "Paypal");

            var switcher = new Gtk.StackSwitcher();
            switcher.set_stack(stack);

            content_box.add(switcher);
            content_box.add(stack);

            this.get_content_area().add(content_box);
            stack.set_visible_child(coinbase_view);
        }

    }
}