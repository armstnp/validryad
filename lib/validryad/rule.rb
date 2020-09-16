# frozen_string_literal: true

require 'validryad/combinators'
require 'validryad/error'
require 'dry/monads'

module Validryad
  class Rule
    include Combinators
    include Dry::Monads[:result]

    def initialize(error: :rule_failed, predicate:)
      @error     = error
      @predicate = predicate
    end

    def call(value, path, context)
      unless (0..3).include? predicate.arity
        raise Error,
              "Rule predicate must accept 0-3 params: value, path, context; given: #{predicate}"
      end

      params = [value, path, context].first predicate.arity
      predicate.call(*params) ? Success(value) : Failure([[error, path]])
    end

    private

    attr_reader :error, :predicate
  end
end