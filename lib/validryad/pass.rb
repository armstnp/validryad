# frozen_string_literal: true

require 'validryad/combinators'
require 'dry/monads'

module Validryad
  class Pass
    include Combinators
    include Dry::Monads[:result]

    def self.instance
      @instance ||= new
    end

    def call(value, _path, _context)
      Success value
    end
  end
end