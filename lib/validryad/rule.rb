# frozen_string_literal: true

require 'validryad/context'
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

    def call(value, context = Context.new(value))
      unless (0..2).include? predicate.arity
        raise Error,
              "Rule predicate must accept 0-2 params: value, context; given: #{predicate}"
      end

      params = [value, context].first predicate.arity
      predicate.call(*params) ? Success(value) : context.fail(error)
    end

    private

    attr_reader :error, :predicate
  end
end