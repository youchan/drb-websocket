require 'drb/drb'
require 'drb/websocket'
require 'thread'
require 'rack'
require 'faye/websocket'

module DRb
  module WebSocket

    def self.open_server(uri, config)
      unless uri =~ /^ws:\/\/(.*?):(\d+)(\?(.*))?$/
        raise(DRbBadScheme, uri) unless uri =~ /^ws:/
        raise(DRbBadURI, 'can\'t parse uri:' + uri)
      end
      Server.new(uri, config)
    end

    class Callback
      def initialize(drb)
        @drb = drb
        @queue = Thread::Queue.new
      end

      def recv_mesg(msg)
        @msg = msg
        @drb.push(self)
        @queue.pop
      end

      def message
        @msg
      end

      def reply(body)
        @queue.push(body)
      end

      def close; end
    end

    class Server
      attr_reader :uri

      def initialize(uri, config)
        @uri = uri
        @config = config
        @queue = Thread::Queue.new
        setup_websock(uri)
      end

      def close
        @ws.close if @ws
        @ws = nil
      end

      def push(callback)
        @queue.push(callback)
      end

      def accept
        client = @queue.pop
        ServerSide.new(client, @config, uri)
      end

      def setup_websock(uri)
        u = URI.parse(uri)
        callback = Callback.new(self)

        app = lambda do |env|
          if Faye::WebSocket.websocket?(env)
            ws = Faye::WebSocket.new(env)

            ws.on :message do |event|
              res = callback.recv_mesg(event.data.pack('C*'))
              ws.send res.bytes
            end

            ws.on :close do |event|
              ws = nil
            end

            @ws = ws
            @queue.push(callback)

            # Return async Rack response
            ws.rack_response
          else
            # Normal HTTP request
            [400, {}, []]
          end
        end

        Thread.new do
          Rack::Server.start app: app, Host: u.host, Port: u.port
        end.run
      end
    end

    class ServerSide
      attr_reader :uri

      def initialize(callback, config, uri)
        @uri = uri
        @callback = callback
        @config = config
        @msg = DRbMessage.new(@config)
        @req_stream = StrStream.new(@callback.message)
      end

      def close
        @callback.close if @callback
        @callback = nil
      end

      def alive?; false; end

      def recv_request
        begin
          @msg.recv_request(@req_stream)
        rescue
          close
          raise $!
        end
      end

      def send_reply(succ, result)
        begin
          return unless @callback
          stream = StrStream.new
          @msg.send_reply(stream, succ, result)
          @callback.reply(stream.buf)
        rescue
          close
          raise $!
        end
      end
    end
  end
end
