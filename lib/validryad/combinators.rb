# frozen_string_literal: true

require 'validryad/context'
require 'validryad/error'
require 'dry/monads'

module Validryad
  module Combinators
    def &(other)
      And.new self, other
    end

    def >(other)
      Then.new self, other
    end

    def >=(other)
      Implies.new self, other
    end

    # Or is very difficult to express simply: how do you respond that a value satisfied neither of two
    # conditions, when only satisfying one would suffice? [:neither err_l err_r]? [:both err_l err_r]?
    # Consider recommending that such conditions be flipped via deMorgan's law, and further consider
    # how a Not predicate might work, given it's not clear how to invert arbitrary error messages.
    # Unless you could provide an inversion table with a given validation...
  end

  class And
    include Combinators
    include Dry::Monads[:result]

    def initialize(left, right)
      @left  = left
      @right = right
    end

    def call(value, context = Context.new(value))
      case [left.call(value, context), right.call(value, context)]
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

  # A short-circuiting variant of Validryad::And that passes the successful output of the left-hand
  # validation to the right-hand validation. This permits e.g. coerced values to be transformed for
  # use in further validation.
  class Then
    include Combinators
    include Dry::Monads[:result, :do]

    def initialize(left, right)
      @left  = left
      @right = right
    end

    def call(value, context = Context.new(value))
      lvalue = yield left.call value, context
      right.call lvalue, context
    end

    private

    attr_reader :left, :right
  end

  # A validation that uses its left validation as a gate; if it fails, the input value is output as
  # a success, effectively skipping the validation. But if it succeeds, the right validation is run
  # on the same value, and the result is the result of this full validation. In effect, the left
  # validation implies the right validation, in the logical sense.
  #
  # This behaves like Validryad::And and not Validryad::Then, insofar as the same value is delivered
  # to both sides; the output of the left side is not supplied to the right.
  class Implies
    include Combinators
    include Dry::Monads[:result]

    def initialize(left, right)
      @left  = left
      @right = right
    end

    def call(value, context = Context.new(value))
      left
        .call(value, context)
        .either ->(_) { right.call value, context }, ->(_) { Success value }
    end

    private

    attr_reader :left, :right
  end
end