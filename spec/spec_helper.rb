$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'elaios'

require 'timeout'
require 'optparse'
require 'socket'
require 'ostruct'
require 'net/http'
require 'webrick'
require 'eventmachine'
require 'sinatra/base'
require 'stomp_server_ng'
require 'stomp'

require_relative 'helpers/integration_helpers'

Thread.abort_on_exception = true

RSpec.configure do |c|
  c.include IntegrationHelpers, integration: true
end
