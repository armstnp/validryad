# frozen_string_literal: true

require 'validryad/combinators'
require 'dry/monads'

module Validryad
  class Defaulting
    include Combinators
    include Dry::Monads[:result]

    def initialize(default:)
      @default = default
    end

    def call(value, _path, _context)
      Success(value.nil? ? @default : value)
    end
  end
end