# frozen_string_literal: true

require 'validryad/combinators'
require 'dry/monads'

module Validryad
  class Tuple
    include Combinators
    include Dry::Monads[:result, :do]

    def initialize(*elements)
      @element_validators = elements
    end

    def call(value, path, context)
      yield affirm_is_array value, path
      yield validate_size value, path

      element_results = validate_elements value, path, context

      gather_results element_results
    end

    private

    def affirm_is_array(value, path)
      value.is_a?(Array) ? Success(value) : Failure([[[:expected_type, 'Array'], path]])
    end

    def validate_size(value, path)
      expected_size = element_validators.size
      if value.size == expected_size
        Success(value)
      else
        Failure([[[:expected_size, expected_size], path]])
      end
    end

    def validate_elements(value, path, context)
      element_validators
        .zip(value)
        .each_with_index
        .map { |(validator, element), index| validator.call element, path + [index], context }
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

    attr_reader :element_validators
  end
end