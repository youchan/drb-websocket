require 'drb/drb'
require 'drb/websocket_server'

class SampleObject
  def test
    "ACK!"
  end
end

DRb.start_service("ws://127.0.0.1:1234", SampleObject.new)
DRb.thread.join
