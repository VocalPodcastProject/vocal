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
    public class XmlUtils {

        public static string strip_trailing_rss_chars(string rss) {
            // If there is a feed tag , it is atom file, else a rss one.
            if (rss.last_index_of("</feed>")>0)
                return rss.substring(0, rss.last_index_of("</feed>") + "</feed>".length);
            else
                return rss.substring(0, rss.last_index_of("</rss>") + "</rss>".length);
        }
    
        public static unowned Xml.Doc parse_string (string? input_string) throws PublishingError {
            if (input_string == null || input_string.length == 0) {
                throw new PublishingError.MALFORMED_RESPONSE ("Empty XML string");
            }

            var rss = strip_trailing_rss_chars(input_string);
    
            // Does this even start and end with the right characters?
            if (!rss.chug ().chomp ().has_prefix ("<") ||
            !rss.chug ().chomp ().has_suffix (">")) {
                // Didn't start or end with a < or > and can't be parsed as XML - treat as malformed.
                throw new PublishingError.MALFORMED_RESPONSE ("Unable to parse XML document 1");
            }

            // Don't want blanks to be included as text nodes, and want the XML parser to tolerate
            // tolerable XML
            Xml.Doc *doc = Xml.Parser.read_memory (rss, (int) rss.length, null, null,
            Xml.ParserOption.NOBLANKS | Xml.ParserOption.RECOVER);
            if (doc == null)
                throw new PublishingError.MALFORMED_RESPONSE ("Unable to parse XML document 2");

            // Since 'doc' is the top level, if it has no children, something is wrong
            // with the XML; we cannot continue normally here.
            if (doc->children == null) {
                throw new PublishingError.MALFORMED_RESPONSE ("Unable to parse XML document 3");
            }

            return doc;
        }
    }
}