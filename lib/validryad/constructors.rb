# frozen_string_literal: true

require 'validryad/pass'
require 'validryad/typed'
require 'validryad/defaulting'
require 'validryad/array_v'
require 'validryad/hash_v'
require 'validryad/tuple'
require 'validryad/rule'

module Validryad
  module Constructors
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
    # @param [:keep|:trim|:reject] other_keys: A mode switch that determines whether unspecified
    # keys are kept without validation (+:keep+), trimmed away from the returned value (+:trim+), or
    # rejected with a failure (+:reject+).
    def hash(full: Pass.instance, mandatory: {}, optional: {}, other_keys: :keep)
      HashV.new full: full, mandatory: mandatory, optional: optional, other_keys: other_keys
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
end