module osc.server;

import std.socket;
import std.container;
import core.thread;
import core.sync.mutex;
import osc.message;
import osc.packet;
import osc.bundle;


/++
+/
class PullServer {
    public{
        this(ushort port){
            this(new InternetAddress ("localhost", port));
        }

        ///
        this(InternetAddress internetAddress){
            import std.socket;
            _socket = new UdpSocket();
            _socket.bind (internetAddress);
        }

        const(Message)[] receive(){
            // while(true){
            const(Message)[] messages;
            size_t l;
            do{
                ubyte[1500] recvRaw;
                l = _socket.receive(recvRaw);
                if(l>0){
                    messages ~= Packet(recvRaw[0..l]).messages;
                }
            }while(l>0);
            return messages;
        }
    }//public

    private{
        UdpSocket _socket;
    }//private
}//class PullServer

/++
+/
class Server {
private:
    bool shouldRun;
    Messages _messages;
    Thread _thread;
    
    void receive(Socket socket){
        ubyte[1500] recvRaw;
        while(shouldRun){
            ptrdiff_t l = socket.receive(recvRaw);
            if (l != UdpSocket.ERROR) {
                _messages.pushMessages(Packet(recvRaw[0..l]).messages);
            }
        }
    }

public:

    /// Construct a server
    this(ushort port){
        this(new InternetAddress ("localhost", port));
    }
    
    ///
    this(InternetAddress internetAddress){
        import std.socket;
        _messages = new Messages;
        auto socket = new UdpSocket();
        socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 16);
        socket.bind (internetAddress);

        shouldRun = true;
        _thread = new Thread(() => receive(socket));
        _thread.start();
    }
    
    ///
    ~this(){
    }

    const(Message)[] popMessages(){
        // const(Message) m = _messages[0];
        // _messages = _messages[1..$];
        return _messages.popMessages;
    }

    void close(){
        if(_thread) {
            shouldRun = false;
            _thread.join;
        }
    }
    
    // bool hasMessage()const{
    //     auto numMessages = _messages.length;
    //
    //     return _messages.length != 0;
    // }
}//class Server

/++
+/
private class Messages {
    public{
        Mutex mtx;
        this(){
            mtx = new Mutex();
        }

        const(Message)[] popMessages(){
            mtx.lock; scope(exit)mtx.unlock;
            const(Message)[] result = cast(const(Message)[])(_contents);
            _contents = [];
            return result;
        }

        void pushMessages(const(Message)[] messages){
            mtx.lock;
            _contents ~= cast(const(Message)[])messages;
            mtx.unlock;
        }
    }//public

    private{
        const(Message)[] _contents;
    }//private
}//class Messages

private{
    const(Message)[] messages(in Packet packet){
        const(Message)[] list;
        if(packet.hasMessage){
            list ~= packet.message;
        }
        if(packet.hasBundle){
            list = messagesRecur(packet.bundle);
        }
        return list;
        
    }
    
    const(Message)[] messagesRecur(in Bundle bundle){
        const(Message)[] list;
        foreach (ref element; bundle.elements) {
            if(element.hasMessage){
                list ~= element.message;
            }
            if(element.hasBundle){
                list ~= element.bundle.messagesRecur;
            }
        }
        return list;
    }
}
