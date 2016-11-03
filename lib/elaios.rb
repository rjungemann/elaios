require 'logger'
require 'json'
require 'securerandom'
require 'simple/queue'

require 'elaios/version'

module Elaios
end

require 'elaios/requester'
require 'elaios/responder'

module Elaios
  # For backwards-compatibility.
  Elaios::Client = Elaios::Requester
  Elaios::Server = Elaios::Responder
end
