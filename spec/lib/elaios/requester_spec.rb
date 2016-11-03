require 'spec_helper'

describe Elaios::Requester do
  [:push, :<<, :enq].each do |name|
    describe "##{name}" do
      it 'pushes a message to the client for processing'
    end
  end

  [:pop, :deq, :shift].each do |name|
    describe "##{name}" do
      it 'pops a message off the client to be sent to the server'
    end
  end

  describe '#method_missing' do
    it 'makes a JSON-RPC method call'
  end

  describe '#update' do
    it 'processes one request to the client'
  end
end
