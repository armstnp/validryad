# frozen_string_literal: true

require 'validryad/context'

RSpec.describe Validryad::Context do
  it 'raises an error when attempting to move to the parent while at the root' do
    expect { Validryad::Context.new(0).parent }.to raise_error Validryad::Error
  end

  it 'moves to the parent' do
    expect(Validryad::Context.new({ a: { b: 2 } }, %i[a b]).parent.value).to eq({ b: 2 })
  end

  it 'moves to a hash child' do
    expect(Validryad::Context.new({ a: { b: 2 } }, [:a]).child(:b).value).to eq 2
  end

  it 'moves to an array child' do
    expect(Validryad::Context.new({ a: [10, 20, 30] }, [:a]).child(1).value).to eq 20
  end

  it 'moves to a hash sibling' do
    expect(Validryad::Context.new({ a: 10, b: 20 }, [:a]).sibling(:b).value).to eq 20
  end

  it 'moves to an array sibling' do
    expect(Validryad::Context.new([10, 20], [0]).sibling(1).value).to eq 20
  end

  it 'fails at the current path' do
    expect(Validryad::Context.new(0, %i[a b]).fail(:error).failure).to eq [[:error, %i[a b]]]
  end
end
