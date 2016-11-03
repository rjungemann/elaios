require 'spec_helper'

describe Elaios::Responder do
  [:push, :<<, :enq].each do |name|
    describe "##{name}" do
      it 'pushes a message to the responder for processing' do
        requests = []
        responder = Elaios::Responder.new
        responder.foo do |data|
          raise 'This method should not be called.'
        end
        responder.bar do |data|
          requests << data
        end
        responder.send(name, '{"method":"bar","id":1,"params":[1,2,3]}')
        expect(requests).to eq([
          { 'method' => 'bar', 'id' => 1, 'params' => [1, 2, 3] }
        ])
      end
    end
  end

  [:pop, :deq, :shift].each do |name|
    describe "##{name}" do
      it 'pops a message off the responder to be sent to the client' do
        responses = []
        responder = Elaios::Responder.new
        expect(responder.send(name)).to be_nil
        responder.res('foo', 1, [1, 2, 3])
        responder.err('bar', 2, 'Something wrong happened.')
        expect(responder.pop).to \
          eq('{"jsonrpc":"2.0","method":"foo","result":[1,2,3],"id":1}')
        expect(responder.pop).to \
          eq('{"jsonrpc":"2.0","method":"bar","error":"Something wrong happened.","id":2}')
        expect(responder.pop).to be_nil
      end
    end
  end

  [:process, :pushpop, :push_pop].each do |name|
    describe "##{name}" do
      it 'pushes a message to the responder, updates it, and pops it off' do
        requests = []
        responder = Elaios::Responder.new
        responder.foo do |data|
          raise 'This method should not be called.'
        end
        responder.bar do |data|
          requests << data
          res('bar', 1, [4, 5])
        end
        responder.baz do |data|
          requests << data
          res('baz', 2, 'Some error occurred.')
        end
        response = responder.send(name, '{"method":"bar","id":1,"params":[1,2,3]}')
        expect(response).to \
          eq('{"jsonrpc":"2.0","method":"bar","result":[4,5],"id":1}')
        response = responder.send(name, '{"method":"baz","id":2,"params":[4,5]}')
        expect(response).to \
          eq('{"jsonrpc":"2.0","method":"baz","result":"Some error occurred.","id":2}')
        expect(responder.pop).to be_nil
        expect(requests).to eq([
          { 'method' => 'bar', 'id' => 1, 'params' => [1, 2, 3] },
          { 'method' => 'baz', 'id' => 2, 'params' => [4, 5] }
        ])
      end
    end
  end

  describe '#method_missing' do
    it 'sets up a handler'
  end

  [:res, :response].each do |name|
    describe "##{name}" do
      it 'generates a success response on the responder for popping'
    end
  end

  [:err, :error].each do |name|
    describe "##{name}" do
      it 'generates an error response on the responder for popping'
    end
  end

  describe '#update' do
    it 'processes one request to the responder'
  end

  describe '#unsafe_push' do
    it 'pushes a message to the responder for processing'
  end

  describe '#unsafe_pop' do
    it 'pops a message off the responder to be sent to the client'
  end
end
