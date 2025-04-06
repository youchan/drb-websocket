require 'thread'
require 'rack'
require 'rackup'
require 'puma'
require 'faye/websocket'

module DRb
  module WebSocket

    def self.open_server(uri, config)
      unless uri =~ /^wss?:\/\/(.*?)(:(\d+))?(\/(.*))?$/
        raise(DRbBadScheme, uri) unless uri =~ /^ws:/
        raise(DRbBadURI, 'can\'t parse uri: ' + uri)
      end

      if $4 == 'callback'
        CallbackServer.new(uri, config)
      else
        Server.new(uri, config)
      end
    end

    class Server
      attr_reader :uri

      def initialize(uri, config)
        @uri = uri
        @config = config
        @queue = Thread::Queue.new
        Faye::WebSocket.load_adapter('puma')

        u = URI.parse(uri)
        RackApp.register(uri, self)

        if RackApp.config.standalone
          Thread.new do
            app = RackApp.new(-> { [400, {}, []] })
            Rackup::Server.start app:app, Port: u.port
          end.run
        end
      end

      def close
      end

      def accept
        ws = @queue.pop
        ServerSide.new(ws, @config, uri)
      end

      def on_message(data)
      end

      def on_session_start(ws)
        @queue.push(ws)
      end
    end

    class Messages
      def initialize
        @request_message = Thread::Queue.new
        @reply_message = Thread::Queue.new
      end

      def recv_message(message)
        @request_message.push message
        @reply_message.pop
      end

      def request_message
        @request_message.pop
      end

      def reply(body)
        @reply_message.push(body)
      end
    end

    class ServerSide
      attr_reader :uri

      def initialize(ws, config, uri)
        @uri = uri
        @config = config
        @msg = DRbMessage.new(@config)
        @ws = ws

        @messages = Messages.new
        @ws.on(:message) do |event|
          message = event.data
          sender_id = message.shift(36)
          EM.defer do
            res = @messages.recv_message(message.pack('C*'))
            if @ws
              @ws.send(sender_id + res.bytes)
            else
              puts 'Socket is already closed.'
            end
          end
        end
      end

      def close
        EM.defer do
          @ws.close if @ws
          @ws = nil
        end
      end

      def alive?
        !!@ws
      end

      def recv_request
        begin
          @req_stream = StrStream.new(@messages.request_message)
          @msg.recv_request(@req_stream)
        rescue
          close
          raise $!
        end
      end

      def send_reply(succ, result)
        begin
          return unless alive?
          stream = StrStream.new
          @msg.send_reply(stream, succ, result)
          @messages.reply(stream.buf)
        rescue
          close
          raise $!
        end
      end
    end
  end
end
