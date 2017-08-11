require 'drb/drb'
require_relative './rack_app'
require 'drb/websocket'
require 'thread'
require 'rack'
require 'thin'
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

        Faye::WebSocket.load_adapter('thin')

        u = URI.parse(uri)
        RackApp.register("#{u.host}:#{u.port}", self)
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

      def on_message(data)
        callback = Callback.new(self)
        @queue.push(callback)
        callback.recv_mesg(data.pack('C*'))
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
