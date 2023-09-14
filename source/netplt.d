module netplt;

import std.stdio,
			 std.conv,
			 std.socket,
			 std.format;

import core.runtime;

import daplt.daplt;

extern (C) PObj init(){
	Runtime.initialize;
	return moduleCreate!(mixin(__MODULE__))("netplt").obj;
}

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
	@property bool isAlive() const {
		return sock !is null && sock.isAlive;
	}

	/// close and destroy socket
	void close(){
		sock.shutdown(SocketShutdown.BOTH);
		sock.close();
		.destroy(sock);
		sock = null;
		.destroy(buf);
		buf = null;
		rxBytes = 0;
	}
}

/// Adds a new connection from a socket
size_t connAdd(Socket sock){
	foreach (i; 0 .. _conns.length){
		if (_conns[i].sock is null){
			_conns[i] = Connection(sock);
			return i;
		}
	}
	_conns ~= Connection(sock);
	return cast(ptrdiff_t)_conns.length - 1;
}

/// Listener, will be null if not listening
Socket _listener;
/// Active connections.
Connection[] _conns;
/// Port to use
ushort _port = 3001;
/// whether to use ipv6
bool _ipv6 = false;
/// listener backlog
uint _listenerBacklog = 15;

/// Set port
@PExport bool setPort(int port){
	if (port < ushort.min || port > ushort.max)
		return false;
	_port = cast(ushort)port;
	return true;
}

/// Set whether to use ipv6
@PExport void setIpv6(bool enable){
	_ipv6 = enable;
}

/// Whether a connection id is valid
@PExport bool isAlive(int conId){
	return (conId < _conns.length && _conns[conId].isAlive);
}

/// start listener
/// if listener already exists, it is closed
/// Returns: true if done, false if failed
@PExport bool listenerStart(){
	try{
		if (_listener !is null){
			_listener.close();
			_listener = null;
		}
		Address addr;
		if (_ipv6){
			addr = new Internet6Address(_port);
			_listener = new Socket(AddressFamily.INET6, SocketType.STREAM);
		}else{
			addr = new InternetAddress(_port);
			_listener = new Socket(AddressFamily.INET, SocketType.STREAM);
		}
		_listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		_listener.bind(addr);
		_listener.listen(_listenerBacklog);
	} catch (SocketException e){
		debug stderr.writeln("net.plt: ", e.msg);
		_listener = null;
		return false;
	}
	return true;
}

/// stops listener
@PExport void listenerStop(){
	if (_listener is null)
		return;
	_listener.close;
	_listener = null;
}

/// establish new connection
/// Returns: connection ID, or throws
@PExport int connect(string address){
	try{
		Address addr;
		Socket sock;
		if (_ipv6){
			addr = new Internet6Address(address, _port);
			sock = new Socket(AddressFamily.INET6, SocketType.STREAM, ProtocolType.TCP);
		}else{
			addr = new InternetAddress(address, _port);
			sock = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
		}
		sock.connect(addr);
		// find a index
		return cast(int)connAdd(sock);
	} catch (SocketException e){
		debug stderr.writeln("net.plt: ", e.msg);
		return -1;
	}
}

/// Close a connection
/// Returns: true if done fales if not
@PExport bool close(int conId){
	try{
		if (!isAlive(conId))
			return false;
		_conns[conId].close;
		return true;
	} catch (SocketException e){
		debug stderr.writeln("net.plt: ", e.msg);
		return false;
	}
}

/// Returns: local address of a connection, or empty string if error
@PExport string addressLocalOf(int conId){
	try{
		if (!isAlive(conId))
			return "";
		return _conns[conId].sock.localAddress.toAddrString;
	} catch (SocketException e){
		debug stderr.writeln("net.plt: ", e.msg);
		return "";
	}
}

/// Returns: remote address of a connection, or empty string if error
@PExport string addressRemoteOf(int conId){
	try{
		if (!isAlive(conId))
			return "";
		return _conns[conId].sock.remoteAddress.toAddrString;
	} catch (SocketException e){
		debug stderr.writeln("net.plt: ", e.msg);
		return "";
	}
}
