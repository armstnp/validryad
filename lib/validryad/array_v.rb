# frozen_string_literal: true

require 'validryad/combinators'
require 'validryad/pass'
require 'dry/monads'

module Validryad
  class ArrayV
    include Combinators
    include Dry::Monads[:result, :do]

    def initialize(before: Pass.instance, each: Pass.instance, after: Pass.instance)
      @before_validator  = before
      @element_validator = each
      @after_validator   = after
    end

    def call(value, path, context)
      yield affirm_is_array value, path

      before_value = yield before_validator.call value, path, context
      each_value   = yield validate_elements before_value, path, context
      after_validator.call each_value, path, context
    end

    private

    def affirm_is_array(value, path)
      value.is_a?(Array) ? Success(value) : Failure([[[:expected_type, 'Array'], path]])
    end

    def validate_elements(value, path, context)
      validated_elements = value.each_with_index.map do |element, index|
        element_validator.call element, path + [index], context
      end

      gather_results validated_elements
    end

    def gather_results(results)
      results.any?(&:failure?) ? invert_failures(results) : invert_success(results)
    end

    def invert_failures(results)
      Failure(results.select(&:failure?).inject([]) { |agg, failure| agg + failure.failure })
    end

    def invert_success(results)
      Success results.map(&:value!)
    end

    attr_reader :before_validator, :element_validator, :after_validator
  end
end