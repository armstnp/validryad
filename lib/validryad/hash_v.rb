# frozen_string_literal: true

require 'validryad/combinators'
require 'validryad/pass'
require 'dry/monads'

module Validryad
  class HashV
    include Combinators
    include Dry::Monads[:result, :do]

    OTHER_KEY_HANDLERS = {
      keep:   ->(k, v, _path) { [k, Dry::Monads.Success(v)] },
      trim:   ->(_k, _v, _path) { nil },
      reject: ->(k, _v, path) { [k, Dry::Monads.Failure([[[:invalid_key, k], path]])] }
    }.freeze

    def initialize(full: Pass.instance, mandatory: {}, optional: {}, other_keys: :keep)
      @full_validator    = full
      @key_validators    = mandatory.merge optional
      @mandatory_keys    = mandatory.keys
      @other_key_handler = OTHER_KEY_HANDLERS[other_keys]

      raise Validryad::Error, "Invalid other-key handler #{other_keys}" unless other_key_handler
    end

    def call(value, path, context)
      yield affirm_is_hash value, path

      full_value = yield full_validator.call value, path, context

      element_results     = validate_elements full_value, path, context
      missing_key_results = validate_mandatory_present full_value, path
      all_results         = element_results + missing_key_results

      gather_results all_results
    end

    private

    def affirm_is_hash(value, path)
      value.is_a?(Hash) ? Success(value) : Failure([[[:expected_type, 'Hash'], path]])
    end

    def validate_elements(value, path, context)
      value.map do |key, val|
        if validated_key? key
          validate_kv key, val, path, context
        else
          other_key_handler.call key, val, path
        end
      end.compact
    end

    def validated_key?(key)
      key_validators.key? key
    end

    def validate_kv(key, value, path, context)
      [key, key_validators[key].call(value, path + [key], context)]
    end

    def validate_mandatory_present(value, path)
      mandatory_keys
        .reject { |key| value.key? key }
        .map { |key| [key, Failure([[[:missing_key, key], path]])] }
    end

    def gather_results(results)
      results.any? { |(_k, v)| v.failure? } ? invert_failures(results) : invert_success(results)
    end

    def invert_failures(results)
      Failure(
        results
          .map { _1[1] } # second
          .select(&:failure?)
          .inject([]) { |agg, failure| agg + failure.failure }
      )
    end

    def invert_success(results)
      Success(results.map { |(k, v)| [k, v.value!] }.to_h)
    end

    attr_reader :full_validator, :key_validators, :mandatory_keys, :other_key_handler
  end
end