module net;

import crypto.rsa;

import std.socket,
			 std.conv;

/// A network event
struct NetEvent{
	/// Possible types
	enum Type{
		/// A message received
		Message,
		/// A connection was accepted by listener
		ConnAccepted,
		/// Remote closed the connection
		ConnClosed,
		/// No event
		None,
	}
	/// connection ID
	ulong conn;
	/// Message bytes that have been received as of yet
	ubyte[] msg;
	/// message size expected
	size_t msgSize;
}

/// A connection (socket + message buffer)
struct Connection{
	/// Socket
	Socket sock;
	/// Buffer
	ubyte[] buf;
	/// Number of bytes received in buffer so far
	size_t rxBytes;
	/// Maximum message size. If sends greater than this, close connection
	/// Default is 64 KiB
	size_t msgSizeMax = 1 << 16;
	/// Whether this connection is alive
	@property bool isAlive() const pure {
		return sock !is null;
	}
}

/// Listener, will be null if not listening
Socket _listener;
/// Active connections.
Connection[] _conns;

/// process incoming data for a Connection
/// Returns: resulting message(s)
private ubyte[][] _incomingData(Connection conn, char[] buffer){

}
