module DRb
  module WebSocket
    class RackApp
      def initialize(app)
        @app = app
      end

      @servers = {}
      @ws = {}

      def self.server(key)
        @servers[key]
      end

      def self.ws
        @ws
      end

      def self.close(key)
        if @ws.has_key?(key)
          @ws[key].close
          @ws.delete(key)
        end
      end

      def self.register(key, server)
        @servers[key] = server
      end

      def call(env)
        if Faye::WebSocket.websocket?(env)
          ws = Faye::WebSocket.new(env)
          req = Rack::Request.new(env)
          key = "#{req.host}:#{req.port}"
          RackApp.ws[key] = ws

          ws.on :message do |event|
            res = RackApp.server(key).on_message(event.data)
            ws.send res.bytes
          end

          ws.on :close do |event|
            ws = nil
          end

          # Return async Rack response
          ws.rack_response
        else
          @app.call(env)
        end
      end
    end
  end
end
