require 'uri'
require 'eventmachine'
require 'faye/websocket'

module DRb
  module WebSocket
    def self.open(uri, config)
      unless uri =~ /^ws:\/\/(.*?):(\d+)(\/(.*))?$/
        raise(DRbBadScheme, uri) unless uri =~ /^ws:/
        raise(DRbBadURI, 'can\'t parse uri: ' + uri)
      end

      path, uuid = $4.split('/') if $4

      unless path.nil? || path == 'callback'
        raise(DRbBadURI, 'can\'t parse uri: ' + uri)
      end

      handler = RackApp.handler(uri)
      callback_handler = handler || StandaloneCallbackHandler.new(uri, config)
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
      end

      def on_session_start(ws)
        @ws = ws
      end

      def stream
        @queue.pop
      end

      def send(url, data)
        @ws.send(data.bytes)
      end
    end

    class StandaloneCallbackHandler
      def initialize(uri, config)
        @uri = uri
        @config = config
        @queue = Thread::Queue.new
      end

      def stream
        @queue.pop
      end

      def fiber=(fiber)
        @fiber = fiber
      end

      def send(uri, data)
        it = URI.parse(uri)
        path = [(it.path=='' ? '/' : it.path), it.query].compact.join('?')

        Thread.new do
          EM.run do
            ws = Faye::WebSocket::Client.new(uri + path)

            ws.on :message do |event|
              sio = StrStream.new
              sio.write(event.data.pack('C*'))
              @queue.push sio

              if @config[:load_limit] < sio.buf.size
                raise TypeError, 'too large packet'
              end

              ws.close

              EM.stop
              @fiber.resume
            end

            ws.send(data.bytes)
          end
        end
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
        @queue = Thread::Queue.new
      end

      def close
      end

      def alive?
        false
      end

      def send_request(ref, msg_id, *arg, &b)
        stream = StrStream.new
        @msg.send_request(stream, ref, msg_id, *arg, &b)
        @handler.send(@uri, stream.buf)
      end

      def recv_reply
        @reply_stream = @handler.stream

        begin
          @msg.recv_reply(@reply_stream)
        rescue
          close
          raise $!
        end
      end
    end
  end
end

