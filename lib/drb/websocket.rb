require "drb/websocket/version"
require 'drb/drb'
require 'uri'
require 'eventmachine'
require 'faye/websocket'

module DRb
  module WebSocket
    class StrStream
      def initialize(str='')
        @buf = str
      end
      attr_reader :buf

      def read(n)
        begin
          return @buf[0,n]
        ensure
          @buf[0,n] = ''
        end
      end

      def write(s)
        @buf.concat s
      end
    end

    def self.uri_option(uri, config)
      return uri, nil
    end

    def self.open(uri, config)
      unless uri =~ /^ws:\/\/(.*?):(\d+)(\/(.*))?$/
        raise(DRbBadScheme, uri) unless uri =~ /^ws:/
        raise(DRbBadURI, 'can\'t parse uri: ' + uri)
      end

      path = $4

      callback_handler = nil
      if path == 'callback'
        callback_handler = CallbackHandler.new(uri)
        RackApp.register(uri, callback_handler)
      elsif path != nil
        raise(DRbBadURI, 'can\'t parse uri: ' + uri)
      end

      ClientSide.new(uri, config, callback_handler)
    end

    class CallbackHandler
      def initialize(uri)
        @uri = uri
        @queue = Thread::Queue.new
      end

      def on_message(data)
        sio = StrStream.new
        sio.write(data.pack('C*'))
        @queue.push sio
        nil
      end

      def pop
        @queue.pop
      end

      def send(data)
        RackApp.sockets[@uri].send(data.bytes)
      end
    end

    class ClientSide
      def initialize(uri, config, handler)
        @uri = uri
        @res = nil
        @config = config
        @msg = DRbMessage.new(config)
        @proxy = ENV['HTTP_PROXY']
        @handler = handler
      end

      def close
      end

      def alive?
        false
      end

      def send_request(ref, msg_id, *arg, &b)
        stream = StrStream.new
        @msg.send_request(stream, ref, msg_id, *arg, &b)
        if @handler
          @handler.send(stream.buf)
        else
          send(@uri, stream.buf)
        end
      end

      def recv_reply
        @reply_stream = @handler.pop if @handler
        begin
          @msg.recv_reply(@reply_stream)
        rescue
          close
          raise $!
        end
      end

      def send(uri, data)
        @reply_stream = StrStream.new
        it = URI.parse(uri)
        path = [(it.path=='' ? '/' : it.path), it.query].compact.join('?')

        EM.run do
          sio = StrStream.new
          @ws = Faye::WebSocket::Client.new(uri + path)

          @ws.on :message do |event|
            sio.write(event.data.pack('C*'))

            if @config[:load_limit] < sio.buf.size
              raise TypeError, 'too large packet'
            end

            @reply_stream = sio
            @ws.close

            EM.stop
          end

          @ws.send(data.bytes)
        end
      end
    end
  end

  DRbProtocol.add_protocol(WebSocket)
end
