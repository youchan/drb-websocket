module DRb
  module WebSocket
    class CallbackServer
      attr_reader :uri

      def initialize(uri, config)
        @uri = uri
        @config = config
        @queue = Thread::Queue.new
        reconnect
      end

      def reconnect
        @wsclient = WSClient.new(uri)

        @wsclient.on(:message) do |event|
          message = event.data
          sender_id = message.shift(36).pack('C*')
          @queue << [sender_id, message.pack('C*')]
        end
      end

      def close
        EM.defer do
          @wsclient.close
          @wsclient = nil
        end
      end

      def accept
        (sender_id, message) = @queue.pop
        server_side = ServerSide.new(@wsclient, sender_id, message, @config, @uri)
        reconnect
        server_side
      end

      class ServerSide
        attr_reader :uri

        def initialize(wsclient, sender_id, message, config, uri)
          @message = message
          @sender_id = sender_id
          @wsclient = wsclient
          @uri = uri
          @config = config
          @msg = DRbMessage.new(@config)
        end

        def close
          @wsclient = nil
        end

        def alive?
          !!@wsclient
        end

        def recv_request
          begin
            @req_stream = StrStream.new(@message)
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
            @wsclient.send((@sender_id + stream.buf).bytes)
          rescue
            puts $!.full_message
            close
            raise $!
          end
        end
      end
    end
  end
end
