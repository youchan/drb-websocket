require "drb/websocket/version"
require 'drb/drb'
require 'drb/websocket/rack_app'

module DRb
  module WebSocket
    class StrStream
      def initialize(str='')
        @buf = str
      end
      attr_reader :buf

      def read(n)
        begin
          return @buf[0,n]
        ensure
          @buf[0,n] = ''
        end
      end

      def write(s)
        @buf.concat s
      end
    end

    def self.uri_option(uri, config)
      return uri, nil
    end
  end

  DRbProtocol.add_protocol(WebSocket)
end

require 'drb/websocket/ws_client'
require 'drb/websocket/client'
require 'drb/websocket/server'
