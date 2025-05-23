lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'drb/websocket/version'

Gem::Specification.new do |spec|
  spec.name          = "drb-websocket"
  spec.version       = Drb::Websocket::VERSION
  spec.authors       = ["youchan"]
  spec.email         = ["youchan01@gmail.com"]

  spec.summary       = %q{A druby protocol of WebSocket.}
  spec.description   = %q{A druby protocol of WebSocket.}
  spec.homepage      = "https://github.com/youchan/drb-websocket"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

#  spec.add_dependency 'drb'
  #spec.add_dependency 'base64'
  spec.add_dependency 'faye-websocket'
  spec.add_dependency 'rack', '~> 3.0'
  spec.add_dependency 'rackup'
  spec.add_dependency 'puma'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
