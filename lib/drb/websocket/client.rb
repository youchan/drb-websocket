require 'uri'
require 'eventmachine'
require 'faye/websocket'

module DRb
  module WebSocket
    def self.open(uri, config)
      unless uri =~ /^wss?:\/\/(.*?):(\d+)(\/(.*))?$/
        raise(DRbBadScheme, uri) unless uri =~ /^wss?:/
        raise(DRbBadURI, 'can\'t parse uri: ' + uri)
      end

      path, uuid = $4.split('/') if $4

      unless path.nil? || path == 'callback'
        raise(DRbBadURI, 'can\'t parse uri: ' + uri)
      end

      handler = RackApp.handler(uri) || Handler.new(uri, config)
      ClientSide.new(uri, config, handler)
    end

    class CallbackHandler
      def initialize(uri)
        @uri = uri
        @queue = Thread::Queue.new
        @sender_id = SecureRandom.uuid
      end

      def on_message(data)
        sender_id = data.shift(36).pack('C*')

        if sender_id == @sender_id
          sio = StrStream.new
          sio.write(data.pack('C*'))
          @queue.push sio
        end
      end

      def on_session_start(ws)
        @ws = ws
      end

      def stream
        @queue.pop
      end

      def send(uri, data)
        @ws.send((@sender_id + data).bytes)
      end
    end

    class Handler
      def initialize(uri, config)
        @uri = uri
        @config = config
        @queue = Thread::Queue.new
        @sender_id = SecureRandom.uuid
      end

      def stream(&block)
        @queue.pop(&block)
      end

      def send(uri, data)
        @wsclient = WSClient.new(uri)
        @wsclient.on(:message) do |event|
          message = event.data
          sender_id = message.shift(36).pack('C*')

          next if sender_id != @sender_id

          sio = StrStream.new
          sio.write(message.pack('C*'))
          @queue.push sio

          if @config[:load_limit] < sio.buf.size
            raise TypeError, 'too large packet'
          end

          @wsclient.close
        end

        @wsclient.on(:open) do
          @wsclient.send((@sender_id + data).bytes)
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
        reply_stream = @handler.stream
        begin
          @msg.recv_reply(reply_stream)
        rescue
          close
          raise $!
        end
      end
    end
  end
end

