require 'drb/drb'
require 'drb/websocket'

class SampleObject
  def test
    "ACK!"
  end
end

class SampleFactory
  def self.get
    DRbObject.new(SampleObject.new)
  end
end

DRb.start_service("ws://127.0.0.1:1234", SampleFactory)
DRb.thread.join
