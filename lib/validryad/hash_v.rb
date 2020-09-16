# frozen_string_literal: true

require 'validryad/context'
require 'validryad/combinators'
require 'validryad/pass'
require 'dry/monads'

module Validryad
  class HashV
    include Combinators
    include Dry::Monads[:result, :do]

    OTHER_KEY_HANDLERS = {
      keep:   ->(k, v, _ctx) { [k, Dry::Monads.Success(v)] },
      trim:   ->(_k, _v, _ctx) { nil },
      reject: ->(k, _v, ctx) { [k, ctx.fail([:invalid_key, k])] }
    }.freeze

    def initialize(
      before:     Pass.instance,
      mandatory:  {},
      optional:   {},
      other_keys: :keep,
      after:      Pass.instance
    )
      @before_validator  = before
      @key_validators    = mandatory.merge optional
      @mandatory_keys    = mandatory.keys
      @other_key_handler = OTHER_KEY_HANDLERS[other_keys]
      @after_validator   = after

      raise Validryad::Error, "Invalid other-key handler #{other_keys}" unless other_key_handler
    end

    def call(value, context = Context.new(value))
      yield affirm_is_hash value, context

      before_value   = yield before_validator.call value, context
      elements_value = yield validate_elements before_value, context
      after_validator.call elements_value, context
    end

    private

    def affirm_is_hash(value, context)
      value.is_a?(Hash) ? Success(value) : context.fail([:expected_type, 'Hash'])
    end

    def validate_elements(value, context)
      element_results     = validate_kvs value, context
      missing_key_results = validate_mandatory_present value, context
      all_results         = element_results + missing_key_results

      gather_results all_results
    end

    def validate_kvs(value, context)
      value.map do |key, val|
        if validated_key? key
          validate_kv key, val, context
        else
          other_key_handler.call key, val, context
        end
      end.compact
    end

    def validated_key?(key)
      key_validators.key? key
    end

    def validate_kv(key, value, context)
      [key, key_validators[key].call(value, context.child(key))]
    end

    def validate_mandatory_present(value, context)
      mandatory_keys
        .reject { |key| value.key? key }
        .map { |key| [key, context.fail([:missing_key, key])] }
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

    attr_reader :before_validator, :key_validators, :mandatory_keys, :other_key_handler,
                :after_validator
  end
end