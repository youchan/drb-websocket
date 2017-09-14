module DRb
  module WebSocket
    class RackApp
      def initialize(app)
        @app = app
        RackApp.config.use_rack = true
      end

      @handlers = {}
      @sockets = {}

      def self.handler(key)
        @handlers[key]
      end

      def self.sockets
        @sockets
      end

      def self.close(key)
        if @sockets.has_key?(key)
          @sockets[key].close
          @sockets.delete(key)
        end
      end

      def self.register(key, handler)
        @handlers[key] = handler
      end

      def call(env)
        if Faye::WebSocket.websocket?(env)
          ws = Faye::WebSocket.new(env)
          req = Rack::Request.new(env)
          uri = "ws://#{req.host}:#{req.port}#{req.path == '/' ? nil : req.path}"
          RackApp.sockets[uri] = ws

          ws.on :message do |event|
            Thread.new do
              res = RackApp.handler(uri).on_message(event.data)
              ws.send(res.bytes) if res
            end.run
          end

          ws.on :close do |event|
            RackApp.close(uri)
            ws = nil
          end

          # Return async Rack response
          ws.rack_response
        else
          @app.call(env)
        end
      end

      def self.config
        @config ||= Config.new
        yield @config if block_given?
        @config
      end

      class Config
        attr_reader :standalone, :callback_url

        def initialize
          @standalone = true
        end

        def use_rack=(flag)
          @standalone = !flag
        end

        def callback_url=(url)
          @callback_url = url
        end
      end
    end
  end
end
