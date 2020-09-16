# frozen_string_literal: true

require 'validryad/context'
require 'validryad/combinators'
require 'dry/monads'

module Validryad
  class Typed
    include Combinators
    include Dry::Monads[:result]

    def initialize(type)
      @type = type
    end

    def call(value, context = Context.new(value))
      type.try(value) { context.fail [:expected_type, type.name] }.to_monad
    end

    private

    attr_reader :type
  end
end