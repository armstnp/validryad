# frozen_string_literal: true

require 'validryad/version'
require 'dry/monads'

module Validryad
  class Error < StandardError; end

  module Combinators
    def &(other)
      And.new self, other
    end

    def >(other)
      Then.new self, other
    end
  end

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

  class Typed
    include Combinators
    include Dry::Monads[:result]

    def initialize(type)
      @type = type
    end

    def call(value, path, _context)
      type.try(value) { Failure [[[:expected_type, type.name], path]] }.to_monad
    end

    private

    attr_reader :type
  end

  class And
    include Combinators
    include Dry::Monads[:result]

    def initialize(left, right)
      @left  = left
      @right = right
    end

    def call(value, path, context)
      case [left.call(value, path, context), right.call(value, path, context)]
      in [Success, Success => success]
        success
      in [Success, Failure => failure]
        failure
      in [Failure => failure, Success]
        failure
      in [Failure(*lerrs), Failure(*rerrs)]
        Failure(lerrs + rerrs)
      else
        raise Error, 'Unexpected failures - invalid validator?'
      end
    end

    private

    attr_reader :left, :right
  end

  # A short-circuiting variant of Validation::And that passes the successful output of the left-hand
  # validation to the right-hand validation. This permits e.g. coerced values to be transformed for
  # use in further validation.
  class Then
    include Combinators
    include Dry::Monads[:result, :do]

    def initialize(left, right)
      @left  = left
      @right = right
    end

    def call(value, path, context)
      lvalue = yield left.call value, path, context
      right.call lvalue, path, context
    end

    private

    attr_reader :left, :right
  end

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

  class HashV
    include Combinators
    include Dry::Monads[:result, :do]

    def initialize(full: Pass.instance, mandatory: {}, optional: {})
      @full_validator = full
      @key_validators = mandatory.merge optional
      @mandatory_keys = mandatory.keys
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
        validated_key?(key) ? validate_kv(key, val, path, context) : [key, Success(val)]
      end
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

    attr_reader :full_validator, :key_validators, :mandatory_keys
  end

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

  class Rule
    include Combinators
    include Dry::Monads[:result]

    def initialize(error:, predicate:)
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

  # Or is very difficult to express simply: how do you respond that a value satisfied neither of two
  # conditions, when only satisfying one would suffice? [:neither err_l err_r]? [:both err_l err_r]?
  # Consider recommending that such conditions be flipped via deMorgan's law, and further consider
  # how a Not predicate might work, given it's not clear how to invert arbitrary error messages.
  # Unless you could provide an inversion table with a given validation...

  module Constructors
    # Validate a value is of a given type. If given a coercible type, will alter the value on
    # successful coercion.
    # @param [#try(val, &) & #name] type The type constraint
    def typed(type)
      Typed.new type
    end

    # Alters a value to a default one if absent (nil), or preserves the existing value if present
    # (non-nil).
    # @param value The value to use as a default
    def default(value)
      Defaulting.new default: value
    end

    # Validate a value is a homogeneous array.
    # @param [#call(val, path, context)] full: A validator to apply to the array as a whole (e.g.
    # count)
    # @param [#call(val, path, context)] each: A validator to apply to each element of the array
    def array(full: Pass.instance, each: Pass.instance)
      ArrayV.new full: full, each: each
    end

    # Validate a value is a hash with specified keys.
    # @param [#call(val, path, context)] full: A validator to apply to the hash as a whole (e.g.
    # count)
    # @param [Hash<Object, #call(val, path, context)>] mandatory: A map of mandatory keys to
    # validators against those keys
    # @param [Hash<Object, #call(val, path, context)>] optional: A map of optional keys to
    # validators against those keys
    def hash(full: Pass.instance, mandatory: {}, optional: {})
      HashV.new full: full, mandatory: mandatory, optional: optional
    end

    # Validate a value is a fixed-size tuple.
    # @param [Array<#call(val, path, context)>] elements Validators for each element of the tuple,
    # in sequence.
    def tuple(*elements)
      Tuple.new(*elements)
    end

    # Validate a value follows a provided rule. The block may take multiple arities, in one of the
    # following forms:
    #   ||
    #   |value|
    #   |value, path|
    #   |value, path, context|
    #
    # @param [Object] error: The error code to use when the value fails the rule.
    # @yieldparam [Object] value The value to be validated
    # @yieldparam [Array<Object>] path The path through the context at which value is located
    # @yieldparam [Object] context The original context in which value was found
    # @yieldreturn [Boolean] Whether the value passes the rule.
    def rule(error:, &predicate)
      Rule.new error: error, predicate: predicate
    end

    # Prefab Predicates

    # Validate a value is present (non-nil)
    def present
      Rule.new error: :absent, predicate: -> { !_1.nil? }
    end

    # Validate a value is absent (nil)
    def absent
      Rule.new error: :present, predicate: -> { _1.nil? }
    end

    # Validates a value is greater than a minimum
    # @param [Object] min The minimum value to compare against
    def gt(min)
      Rule.new error: [:not_gt, min], predicate: -> { _1 > min }
    end

    # Validates a value is greater than or equal to a minimum
    # @param [Object] min The minimum value to compare against
    def gteq(min)
      Rule.new error: [:not_gteq, min], predicate: -> { _1 >= min }
    end

    # Validates a value is less than a maximum
    # @param [Object] max The maximum value to compare against
    def lt(max)
      Rule.new error: [:not_lt, max], predicate: -> { _1 < max }
    end

    # Validates a value is less than or equal to a maximum
    # @param [Object] max The maximum value to compare against
    def lteq(max)
      Rule.new error: [:not_lteq, max], predicate: -> { _1 <= max }
    end

    # Validates a value equals a given value
    # @param [Object] val The value to compare against
    def eq(val)
      Rule.new error: [:not_eq, val], predicate: -> { _1 == val }
    end

    # Validates a value does not equal a given value
    # @param [Object] val The value to compare against
    def neq(val)
      Rule.new error: [:eq, val], predicate: -> { _1 != val }
    end

    # Validates a value is included in a given set
    # @param [#include?(val)] set The set to test for inclusion
    def included_in(set)
      Rule.new error: [:not_included_in, set], predicate: -> { set.include? _1 }
    end

    # Validates a value is excluded from a given set
    # @param [#include?(val)] set The set to test for exclusion
    def excluded_from(set)
      Rule.new error: [:included_in, set], predicate: -> { !set.include? _1 }
    end

    # Validates a value case-matches a given condition
    # @param [#===(val)] case_cond The condition to case-test against
    def matching(case_cond)
      Rule.new error: [:not_matching, case_cond], predicate: -> { case_cond === _1 }
    end
  end

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
