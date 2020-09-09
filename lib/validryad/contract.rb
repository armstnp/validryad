# frozen_string_literal: true

require 'validryad/constructors'

module Validryad
  class Contract
    extend Constructors

    def self.specify(validation)
      @validation = validation
    end

    def self.call(value)
      @validation.call value, [], value
    end
  end
end