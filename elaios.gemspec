# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elaios/version'

Gem::Specification.new do |spec|
  spec.name          = 'elaios'
  spec.version       = Elaios::VERSION
  spec.authors       = ['Roger Jungemann']
  spec.email         = ['roger@thefifthcircuit.com']

  spec.summary       = %q{A transport-agnostic JSON-RPC client-server library.}
  spec.homepage      = 'https://github.com/rjungemann/elaios'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'simple-queue', '~> 0.1.0'
  spec.add_dependency 'em-promise', '~> 1.1.1'
  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'eventmachine', '~> 1.2.0.1'
  spec.add_development_dependency 'sinatra', '~> 2.0.0.beta2'
  spec.add_development_dependency 'stompserver_ng', '~> 1.0.6'
  spec.add_development_dependency 'stomp', '~> 1.4.3'
end
