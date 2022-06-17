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


namespace Vocal {
public class SoupClient {

    public SoupClient () {

    }

    public string request_as_string(HttpMethod method, string url) throws Error {

        var soup_session = new Soup.Session ();
        soup_session.user_agent = Constants.USER_AGENT;
        var message = new Soup.Message (method.to_string (), url);

        var response = soup_session.send (message);

        DataInputStream dis = new DataInputStream (@response);

        size_t len;
		string str = dis.read_upto ("\0", 1, out len);
        check_response_headers (message);
        return str;
    }

    public InputStream request (HttpMethod method, string url) throws Error {

        var soup_session = new Soup.Session ();
        soup_session.user_agent = Constants.USER_AGENT;
        if (!valid_http_uri (url)) {
            throw new PublishingError.PROTOCOL_ERROR ("%s is not a valid URI. Should be http or https", url);
        }

        var message = new Soup.Message (method.to_string (), url);

        InputStream stream = soup_session.send (message);

        check_response_headers (message);

        return stream;
    }

    public static bool valid_http_uri (string url) {
        return url.index_of ("http://") == 0 || url.index_of ("https://") == 0;
    }

    public static bool check_connection () {
        var uri = "https://www.vocalproject.net";

        try {
            SoupClient soup_client = new SoupClient ();
            soup_client.request_as_string (HttpMethod.GET, uri);
        } catch (Error e) {
            warning (e.message);
            return false;
        }

        return true;
    }

    private void check_response_headers (Soup.Message message) throws Error {
        switch (message.status_code) {
            case Soup.Status.OK:
            case Soup.Status.CREATED: // HTTP code 201 (CREATED) signals that a new
                // resource was created in response to a PUT or POST
                break;

            default:
                // status codes below 100 are used by Soup, 100 and above are defined HTTP codes
                if (message.status_code >= 100) {
                    throw new PublishingError.NO_ANSWER ("Service %s returned HTTP status code %u %s",
                    message.get_uri ().to_string (), message.status_code, message.reason_phrase);
                } else {
                    throw new PublishingError.NO_ANSWER (
                        "Failure communicating with %s (error code %u)",
                        message.get_uri ().to_string (),
                        message.status_code
                    );
                }
        }


    }
}

public enum HttpMethod {
    GET,
    POST,
    PUT;

    public string to_string () {
        switch (this) {
        case HttpMethod.GET:
            return "GET";

        case HttpMethod.PUT:
            return "PUT";

        case HttpMethod.POST:
            return "POST";

        default:
            error ("unrecognized HTTP method enumeration value");
        }
    }

    public static HttpMethod from_string (string str) {
        if (str == "GET") {
            return HttpMethod.GET;
        } else if (str == "PUT") {
            return HttpMethod.PUT;
        } else if (str == "POST") {
            return HttpMethod.POST;
        } else {
            error ("unrecognized HTTP method name: %s", str);
        }
    }
}

public errordomain PublishingError {
    /**
     * Indicates that no communications channel could be opened to the remote host.
     *
     * This error occurs, for example, when no network connection is available or
     * when a DNS lookup fails.
     */
    NO_ANSWER,

    /**
     * Indicates that a communications channel to the remote host was previously opened, but
     * the remote host can no longer be reached.
     *
     * This error occurs, for example, when the network is disconnected during a publishing
     * interaction.
     */
    COMMUNICATION_FAILED,

    /**
     * Indicates that a communications channel to the remote host was opened and
     * is active, but that messages sent to or from the remote host can't be understood.
     *
     * This error occurs, for example, when attempting to interact with a RESTful host
     * via XML-RPC.
     */
    PROTOCOL_ERROR,

    /**
     * Indicates that the remote host has received a well-formed message that has caused
     * a server-side error.
     *
     * This error occurs, for example, when the remote host receives a message that should
     * be signed but isn't.
     */
    SERVICE_ERROR,

    /**
     * Indicates that the remote host has sent the local client back a well-formed response,
     * but the response can't be understood.
     *
     * This error occurs, for example, when the remote host sends a response in an XML grammar
     * different from that expected by the local client.
     */
    MALFORMED_RESPONSE,

    /**
     * Indicates that the local client can't access a file or files in local storage.
     *
     * This error occurs, for example, when the local client attempts to read binary data
     * out of a photo or video file that doesn't exist.
     */
    LOCAL_FILE_ERROR,

    /**
     * Indicates that the remote host has rejected the session identifier used by the local
     * client as out-of-date. The local client should acquire a new session identifier.
     */
    EXPIRED_SESSION
}
}
