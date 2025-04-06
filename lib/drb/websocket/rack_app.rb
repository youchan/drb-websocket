module DRb
  module WebSocket
    class RackApp
      def initialize(app)
        @app = app
        RackApp.config.use_rack = true
      end

      @handlers = {}

      def self.handler(key)
        @handlers[key]
      end

      def self.close(key)
        if @handlers.has_key?(key)
          @handlers.delete(key)
        end
      end

      def self.register(key, handler)
        @handlers[key] = handler
      end

      def call(env)
        if Faye::WebSocket.websocket?(env)
          ws = Faye::WebSocket.new(env)
          req = Rack::Request.new(env)
          scheme = req.scheme == 'https' ? 'wss' : 'ws'
          uri = "#{scheme}://#{req.host}:#{req.port}#{req.path == '/' ? nil : req.path}"

          handler = req.path.start_with?('/callback') ? RackApp.register(uri, CallbackHandler.new(uri)) : RackApp.handler(uri)
          handler.on_session_start(ws)

          ws.on :message do |event|
            handler.on_message(event.data)
          end

          ws.on :close do |event|
            if CallbackHandler === handler
              RackApp.close(uri)
            end
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
