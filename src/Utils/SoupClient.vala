namespace Vocal {
public class SoupClient {
    private Soup.Session soup_session = null;

    public SoupClient () {
        soup_session = new Soup.Session ();
        soup_session.user_agent = Constants.USER_AGENT;
    }

    public InputStream request (HttpMethod method, string url) throws Error {
        if (!valid_http_uri(url)) {
            throw new PublishingError.PROTOCOL_ERROR("%s is not a valid URI. Should be http or https", url);
        }

        var message = new Soup.Message (method.to_string (), url);
        InputStream stream = soup_session.send (message);
        check_response_headers(message);

        return stream;
    }

    public uint8[] send_message (HttpMethod method, string url) throws PublishingError {
        if (!valid_http_uri(url)) {
            throw new PublishingError.PROTOCOL_ERROR("%s is not a valid URI. Should be http or https", url);
        }

        var message = new Soup.Message (method.to_string (), url);
        soup_session.send_message (message);
        check_response_headers(message);

        // All valid communication involves body data in the response
        if (message.response_body.data == null || message.response_body.data.length == 0) {
            throw new PublishingError.MALFORMED_RESPONSE ("No response data from %s", message.get_uri().to_string (false));
        }

        return message.response_body.data;
    }

    public static bool valid_http_uri(string url) {
        return url.index_of("http://") == 0 || url.index_of("https://") == 0;
    }

    public static bool check_connection() {
        var uri = "http://www.needleandthread.co";

        try {
            SoupClient soup_client = new SoupClient();
            soup_client.send_message(HttpMethod.GET, uri);
        } catch(Error e) {
            warning(e.message);
            return false;
        }

        return true;
    }

    private void check_response_headers (Soup.Message message) throws PublishingError {
        switch (message.status_code) {
            case Soup.Status.OK:
            case Soup.Status.CREATED: // HTTP code 201 (CREATED) signals that a new
                // resource was created in response to a PUT or POST
                break;

            case Soup.Status.CANT_RESOLVE:
            case Soup.Status.CANT_RESOLVE_PROXY:
                throw new PublishingError.NO_ANSWER ("Unable to resolve %s (error code %u)", message.get_uri().to_string (false), message.status_code);

            case Soup.Status.CANT_CONNECT:
            case Soup.Status.CANT_CONNECT_PROXY:
                throw new PublishingError.NO_ANSWER ("Unable to connect to %s (error code %u)", message.get_uri().to_string (false), message.status_code);

            default:
                // status codes below 100 are used by Soup, 100 and above are defined HTTP codes
                if (message.status_code >= 100) {
                    throw new PublishingError.NO_ANSWER ("Service %s returned HTTP status code %u %s",
                    message.get_uri().to_string (false), message.status_code, message.reason_phrase);
                } else {
                    throw new PublishingError.NO_ANSWER ("Failure communicating with %s (error code %u)", message.get_uri().to_string (false), message.status_code);
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