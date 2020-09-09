# frozen_string_literal: true

require 'validryad/combinators'
require 'dry/monads'

module Validryad
  class Typed
    include Combinators
    include Dry::Monads[:result]

    def initialize(type)
      @type = type
    end

    def call(value, path, _context)
      type.try(value) { Failure [[[:expected_type, type.name], path]] }.to_monad
    end

    private

    attr_reader :type
  end
end