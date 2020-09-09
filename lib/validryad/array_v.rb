# frozen_string_literal: true

require 'validryad/combinators'
require 'validryad/pass'
require 'dry/monads'

module Validryad
  class ArrayV
    include Combinators
    include Dry::Monads[:result, :do]

    def initialize(full: Pass.instance, each: Pass.instance)
      @full_validator    = full
      @element_validator = each
    end

    def call(value, path, context)
      yield affirm_is_array value, path

      full_value = yield full_validator.call value, path, context

      element_results = validate_elements full_value, path, context

      gather_results element_results
    end

    private

    def affirm_is_array(value, path)
      value.is_a?(Array) ? Success(value) : Failure([[[:expected_type, 'Array'], path]])
    end

    def validate_elements(value, path, context)
      value.each_with_index.map do |element, index|
        element_validator.call element, path + [index], context
      end
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

    attr_reader :full_validator, :element_validator
  end
end