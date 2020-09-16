# frozen_string_literal: true

require 'validryad/error'
require 'dry/monads'

module Validryad
  class Context
    include Dry::Monads[:result]

    def initialize(root, path = [])
      @root = root
      @path = path
    end

    def value
      root.dig(*path)
    end

    def parent
      raise Error, 'Cannot fetch the parent of a context already at the root' if path.empty?

      move path[...-1]
    end

    def child(step)
      move(path + [step])
    end

    def sibling(sibling_step)
      move(path[...-1] + [sibling_step])
    end

    def fail(error)
      Failure [[error, path]]
    end

    private

    def move(new_path)
      Context.new root, new_path
    end

    attr_reader :path, :root
  end
end