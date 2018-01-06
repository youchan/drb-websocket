
module DRb
  module WebSocket
    class WSClient
      def initialize(uri)
        WSClient.start

        @handlers = { open: [], message: [] }
        @ws = Faye::WebSocket::Client.new(uri)

        EM.defer do
          @ws.on :open do |event|
            @handlers[:open].each do |proc|
              proc.call event
            end
          end

          @ws.on :message do |event|
            @handlers[:message].each do |proc|
              proc.call event
            end
          end
        end
      end

      def on(event, &block)
        @handlers[event] << block
      end

      def send(data)
        @ws.send(data)
      end

      def close
        @ws.close
        @ws = nil
      end

      def self.start
        if @thread
          return
        end

        @thread = Thread.new do
          EM.run
        end
      end

      def self.thread
        @thread
      end

      def self.stop
        EM.stop
        @thread.join
        @thread = nil
      end
    end
  end
end
