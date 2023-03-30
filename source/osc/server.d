module osc.server;

import std.socket;
import std.container;
import core.thread;
import core.sync.mutex;
import osc.message;
import osc.packet;
import osc.bundle;
import std.datetime : msecs;


/++
+/
class PullServer {
private:
    UdpSocket _socket;
    ubyte[] recvBuffer;

public:
    ~this() {
        close();
    }

    this(ushort port) {
        this(new InternetAddress ("0.0.0.0", port));
    }

    ///
    this(InternetAddress internetAddress) {
        import std.socket;
        _socket = new UdpSocket();
        _socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 16.msecs);
        _socket.bind (internetAddress);
        recvBuffer = new ubyte[ushort.max];
    }

    /**
        Attempts to recieve data from the socket
        If no data is recieved for 16 milliseconds this function returns empty-handed.
    */
    const(Message)[] receive() {
        ptrdiff_t l = _socket.receive(recvBuffer);
        if( l != UdpSocket.ERROR ) {
            return Packet(recvBuffer[0..l]).messages;
        }
        return null;
    }

    void close() {
        _socket.close();
    }
}

/++
+/
class Server {
private:
    bool shouldRun;
    Messages _messages;
    Thread _thread;
    Socket socket;
    ubyte[] recvBuffer;
    
    void receive(Socket socket) {
        while(shouldRun) {
            ptrdiff_t l = socket.receive(recvBuffer);
            if (l != UdpSocket.ERROR) {
                _messages.pushMessages(Packet(recvBuffer[0..l]).messages);
            }
        }
    }

public:

    /// Construct a server
    this(ushort port) {
        this(new InternetAddress ("0.0.0.0", port));
    }
    
    ///
    this(InternetAddress internetAddress) {
        import std.socket;
        _messages = new Messages;
        socket = new UdpSocket();
        recvBuffer = new ubyte[ushort.max];
        socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 16.msecs);
        socket.bind (internetAddress);

        shouldRun = true;
        _thread = new Thread(() => receive(socket));
        _thread.start();
    }
    
    ///
    ~this() {
        close();
    }

    const(Message)[] popMessages() {
        return _messages.popMessages;
    }

    void close() {
        if(_thread) {
            shouldRun = false;
            _thread.join;
        }
        if (socket) {
            socket.close();
        }
    }
}

/++
+/
private class Messages {
private:
        const(Message)[] _contents;
        Mutex mtx;

public:
    this() {
        mtx = new Mutex();
    }

    const(Message)[] popMessages() {
        mtx.lock; scope(exit)mtx.unlock;
        const(Message)[] result = cast(const(Message)[])(_contents);
        _contents = [];
        return result;
    }

    void pushMessages(const(Message)[] messages) {
        mtx.lock;
        _contents ~= cast(const(Message)[])messages;
        mtx.unlock;
    }

    size_t length() const {
        return _contents.length;
    }
}

private{
    const(Message)[] messages(in Packet packet) {
        const(Message)[] list;
        if(packet.hasMessage) {
            list ~= packet.message;
        }
        if(packet.hasBundle) {
            list = messagesRecur(packet.bundle);
        }
        return list;
        
    }
    
    const(Message)[] messagesRecur(in Bundle bundle) {
        const(Message)[] list;
        foreach (ref element; bundle.elements) {
            if(element.hasMessage) {
                list ~= element.message;
            }
            if(element.hasBundle) {
                list ~= element.bundle.messagesRecur;
            }
        }
        return list;
    }
}
