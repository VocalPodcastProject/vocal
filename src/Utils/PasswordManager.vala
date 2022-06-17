/* Copyright 2014-2022 Nathan Dyer and Vocal Project Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Secret;
public class PasswordManager {

    // Note of attribution: this code is heavily inspired by @Alecaddd's PasswordManager on Sequeler
    // https://github.com/Alecaddd/sequeler/blob/master/src/Services/PasswordManager.vala

    private static PasswordManager _default_instance = null;

    public static PasswordManager get_default_instance() {
        if(_default_instance == null)
            _default_instance = new PasswordManager();

        return _default_instance;
    }

	public async void store_password_async (string id, string password) throws GLib.Error {
		var attributes = new GLib.HashTable<string, string> (str_hash, str_equal);
		attributes["id"] = id;
		attributes["schema"] = "com.github.VocalPodcastProject.vocal";

		var key_name = "com.github.VocalPodcastProject.vocal" + "." + id;

		var schema = new Secret.Schema ("com.github.VocalPodcastProject.vocal", Secret.SchemaFlags.NONE,
             "id", Secret.SchemaAttributeType.STRING, "schema", Secret.SchemaAttributeType.STRING);

		bool result = yield Secret.password_storev (schema, attributes, Secret.COLLECTION_DEFAULT, key_name, password, null);

		if (!result) {
			info ("Unable to store password for \"%s\" in libsecret keyring", key_name);
		} else {
		    info ("Password for \"%s\" updated in libsecret keyring", key_name);
		}
	}

	public async string? get_password_async (string id) throws GLib.Error {
		var attributes = new GLib.HashTable<string, string> (str_hash, str_equal);
		attributes["id"] = id;
		attributes["schema"] = "com.github.VocalPodcastProject.vocal";

		var key_name = "com.github.VocalPodcastProject.vocal" + "." + id;

		var schema = new Secret.Schema ("com.github.VocalPodcastProject.vocal", Secret.SchemaFlags.NONE,
             "id", Secret.SchemaAttributeType.STRING, "schema", Secret.SchemaAttributeType.STRING);

		string? password = yield Secret.password_lookupv (schema, attributes, null);

		if (password == null) {
			info ("Unable to fetch password in libsecret keyring for %s", key_name);
			return null;
		}

		return password;
	}

	public async void clear_password_async (string id) throws GLib.Error {
		var attributes = new GLib.HashTable<string, string> (str_hash, str_equal);
		attributes["id"] = id;
		attributes["schema"] = "com.github.VocalPodcastProject.vocal";

		var key_name = "com.github.VocalPodcastProject.vocal" + "." + id;

		var schema = new Secret.Schema ("com.github.VocalPodcastProject.vocal", Secret.SchemaFlags.NONE,
             "id", Secret.SchemaAttributeType.STRING, "schema", Secret.SchemaAttributeType.STRING);

		bool successfully_removed = yield Secret.password_clearv (schema, attributes, null);

		if (!successfully_removed) {
			debug ("Unable to clear password in libsecret keyring for %s", key_name);
		}
	}

	public async void clear_all_passwords_async () throws GLib.Error {
		var attributes = new GLib.HashTable<string, string> (str_hash, str_equal);
		attributes["schema"] = "com.github.VocalPodcastProject.vocal";

        var schema = new Secret.Schema ("com.github.VocalPodcastProject.vocal", Secret.SchemaFlags.NONE,
             "id", Secret.SchemaAttributeType.STRING, "schema", Secret.SchemaAttributeType.STRING);

		bool successfully_removed = yield Secret.password_clearv (schema, attributes, null);

		if (!successfully_removed) {
			info ("Unable to clear all passwords in libsecret");
		}
	}
}
