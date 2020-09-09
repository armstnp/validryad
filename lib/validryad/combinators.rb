# frozen_string_literal: true

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

    def call(value, path, context)
      lvalue = yield left.call value, path, context
      right.call lvalue, path, context
    end

    private

    attr_reader :left, :right
  end
end