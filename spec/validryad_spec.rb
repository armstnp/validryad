# frozen_string_literal: true

require 'dry/monads'

RSpec.describe Validryad do
  it 'has a version number' do
    expect(Validryad::VERSION).not_to be nil
  end
end

RSpec.describe Validryad::Contract do
  using RSpec::Parameterized::TableSyntax
  include Dry::Monads[:result]

  C = Validryad::Contract
  ITSELF = :itself.to_proc

  describe :present do
    where :case_name, :value, :success?, :result_contents do
      'one'   | 1     | true  | 1
      'zero'  | 0     | true  | 0
      'false' | false | true  | false
      'nil'   | nil   | false | [[:absent, []]]
    end

    with_them do
      subject { C.present.call value, [], value }

      it('has the expected result type') { expect(subject.success?).to eq success? }

      it 'has the expected result content' do
        expect(subject.either(ITSELF, ITSELF)).to eq result_contents
      end
    end
  end

  describe :absent do
    where :case_name, :value, :success?, :result_contents do
      'one'   | 1     | false | [[:present, []]]
      'zero'  | 0     | false | [[:present, []]]
      'false' | false | false | [[:present, []]]
      'nil'   | nil   | true  | nil
    end

    with_them do
      subject { C.absent.call value, [], value }

      it('has the expected result type') { expect(subject.success?).to eq success? }

      it 'has the expected result content' do
        expect(subject.either(ITSELF, ITSELF)).to eq result_contents
      end
    end
  end

  describe :typed do
    context 'when the type is strict' do
      let(:type) { T::Strict::Integer }

      where :case_name,  :value, :success?, :result_contents do
        'valid integer'  | 1   | true  | 1
        'invalid float'  | 1.1 | false | [[[:expected_type, 'Integer'], []]]
        'invalid string' | '1' | false | [[[:expected_type, 'Integer'], []]]
        'invalid nil'    | nil | false | [[[:expected_type, 'Integer'], []]]
      end

      with_them do
        subject { C.typed(type).call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'when the type is coercible' do
      let(:type) { T::Coercible::Decimal }

      where :case_name,  :value,         :success?, :result_contents do
        'valid decimal'  | BigDecimal(1) | true  | BigDecimal(1)
        'valid integer'  | 1             | true  | BigDecimal(1)
        'valid string'   | '1.1'         | true  | BigDecimal('1.1')
        'invalid float'  | 1.1           | false | [[[:expected_type, 'BigDecimal'], []]]
        'invalid string' | '0xf'         | false | [[[:expected_type, 'BigDecimal'], []]]
        'invalid nil'    | nil           | false | [[[:expected_type, 'BigDecimal'], []]]
      end

      with_them do
        subject { C.typed(type).call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end
  end

  describe :default do
    where :case_name, :default, :value, :success_contents do
      'value present'   | 0    | 1     | 1
      'value absent'    | 0    | nil   | 0
      'value = default' | 1    | 1     | 1
      'falsey, not nil' | true | false | false
    end

    with_them do
      subject { C.default(default).call value, [], value }

      it('is a success') { is_expected.to be_success }

      it 'has the expected value' do
        expect(subject.value!).to eq success_contents
      end
    end
  end

  describe :tuple do
    let(:type_failure) { Failure [[[:expected_type, 'Array'], []]] }

    context 'empty tuple' do
      where :case_name, :value, :success?, :result_contents do
        'not an array' | nil | false | [[[:expected_type, 'Array'], []]]
        'too big'      | [1] | false | [[[:expected_size, 0], []]]
        'empty array'  | []  | true  | []
      end

      with_them do
        subject { C.tuple.call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'unit tuple' do
      where :case_name,   :value,  :success?, :result_contents do
        'not an array'    | nil    | false | [[[:expected_type, 'Array'], []]]
        'too small'       | []     | false | [[[:expected_size, 1], []]]
        'too big'         | [1, 2] | false | [[[:expected_size, 1], []]]
        'invalid element' | ['x']  | false | [[[:not_eq, 1], [0]]]
        'valid element'   | [1]    | true  | [1]
      end

      with_them do
        subject { C.tuple(C.eq(1)).call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'pair tuple' do
      where :case_name,     :value,        :success?, :result_contents do
        'not an array'      | nil          | false | [[[:expected_type, 'Array'], []]]
        'too small'         | [1]          | false | [[[:expected_size, 2], []]]
        'too big'           | [1, :sym, 3] | false | [[[:expected_size, 2], []]]
        'invalid element 0' | ['1', :sym]  | false | [[[:not_eq, 1], [0]]]
        'invalid element 1' | [1, 'sym']   | false | [[[:not_eq, :sym], [1]]]
        'invalid elements'  | ['1', 'sym'] | false | [[[:not_eq, 1], [0]], [[:not_eq, :sym], [1]]]
        'swapped elements'  | [:sym, 1]    | false | [[[:not_eq, 1], [0]], [[:not_eq, :sym], [1]]]
        'valid element'     | [1, :sym]    | true  | [1, :sym]
      end

      with_them do
        subject { C.tuple(C.eq(1), C.eq(:sym)).call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end
  end

  describe :array do
    context 'when no validators are supplied' do
      where :case_name, :value, :success?, :result_contents do
        'non-array' | { a: 1 }  | false | [[[:expected_type, 'Array'], []]]
        'array'     | [1, 2, 3] | true  | [1, 2, 3]
      end

      with_them do
        subject { C.array.call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'when only full validator supplied' do
      where :case_name, :value, :success?, :result_contents do
        'non-array'    | 4         | false | [[[:expected_type, 'Array'], []]]
        'invalid full' | [1, 2]    | false | [[:too_small, []]]
        'valid full'   | [1, 2, 3] | true  | [1, 2, 3]
      end

      with_them do
        subject { C.array(full: C.rule(error: :too_small) { _1.count >= 3 }).call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'when only element validator supplied' do
      where :case_name,    :value,          :path,         :success?, :result_contents do
        'non-array'        | 4              | []           | false   | [[[:expected_type, 'Array'], []]]
        'invalid element'  | [3, 4, 2, 5]   | []           | false   | [[[:not_gt, 2], [2]]]
        'invalid elements' | [0, '1', 4, 2] | []           | false   | [[[:not_gt, 2], [0]],
                                                                        [[:expected_type, 'Integer'], [1]],
                                                                        [[:not_gt, 2], [3]]]
        'append path'      | [3, 2, 4]      | %i[old path] | false   | [[[:not_gt, 2], [:old, :path, 1]]]
        'valid elements'   | [6, 4, 5, 3]   | []           | true    | [6, 4, 5, 3]
      end

      with_them do
        subject { C.array(each: C.typed(T::Integer) > C.gt(2)).call value, path, value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'when full and element validators are supplied' do
      where :case_name,    :value,     :success?, :result_contents do
        'non-array'        | 1         | false | [[[:expected_type, 'Array'], []]]
        'invalid full'     | [1, 2]    | false | [[:too_small, []]]
        'invalid elements' | [3, 4, 2] | false | [[[:not_gt, 2], [2]]]
        'valid elements'   | [6, 4, 5] | true  | [6, 4, 5]
      end

      with_them do
        subject do
          C.array(
            full: C.rule(error: :too_small) { _1.count >= 3 },
            each: C.typed(T::Integer) > C.gt(2)
          ).call value, [], value
        end

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end
  end

  describe :hash do
    context 'when no validators are supplied' do
      where :case_name, :value, :success?, :result_contents do
        'non-hash' | [[:a, 1]] | false | [[[:expected_type, 'Hash'], []]]
        'hash'     | { a: 1 }  | true  | { a: 1 }
      end

      with_them do
        subject { C.hash.call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'when only full validator supplied' do
      where :case_name, :value, :success?, :result_contents do
        'non-hash'     | 4                    | false | [[[:expected_type, 'Hash'], []]]
        'failing full' | { a: 1, b: 2 }       | false | [[:too_small, []]]
        'passing full' | { a: 1, b: 2, c: 3 } | true  | { a: 1, b: 2, c: 3 }
      end

      with_them do
        subject { C.hash(full: C.rule(error: :too_small) { _1.count >= 3 }).call value, [], value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'when only mandatory key validators supplied' do
      where :case_name, :value,              :path,   :success?, :result_contents do
        'non-hash'    | 4                    | []     | false | [[[:expected_type, 'Hash'], []]]
        'empty hash'  | {}                   | []     | false | [[[:missing_key, :a], []], [[:missing_key, :b], []]]
        'missing key' | { b: 2 }             | []     | false | [[[:missing_key, :a], []]]
        'invalid key' | { a: 2, b: 2 }       | []     | false | [[[:not_eq, 1], [:a]]]
        'append path' | { a: 2, b: 2 }       | [1, 2] | false | [[[:not_eq, 1], [1, 2, :a]]]
        'valid keys'  | { a: 1, b: 2 }       | []     | true  | { a: 1, b: 2 }
        'extra key'   | { a: 1, b: 2, c: 3 } | []     | true  | { a: 1, b: 2, c: 3 }
      end

      with_them do
        subject { C.hash(mandatory: { a: C.eq(1), b: C.eq(2) }).call value, path, value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'when only optional key validators supplied' do
      where :case_name, :value, :path, :success?, :result_contents do
        'non-hash'    | 4              | []     | false | [[[:expected_type, 'Hash'], []]]
        'invalid key' | { a: 2 }       | []     | false | [[[:not_eq, 1], [:a]]]
        'append path' | { a: 2 }       | [1, 2] | false | [[[:not_eq, 1], [1, 2, :a]]]
        'empty hash'  | {}             | []     | true  | {}
        'valid keys'  | { a: 1 }       | []     | true  | { a: 1 }
        'extra key'   | { a: 1, b: 2 } | []     | true  | { a: 1, b: 2 }
      end

      with_them do
        subject { C.hash(optional: { a: C.eq(1) }).call value, path, value }

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end

    context 'when all validators supplied' do
      where :case_name,     :value,                :path,   :success?, :result_contents do
        'non-hash'          | 4                    | []     | false | [[[:expected_type, 'Hash'], []]]
        'invalid full'      | { a: 1 }             | []     | false | [[:too_small, []]]
        'invalid mandatory' | { a: 2, c: 3 }       | []     | false | [[[:not_eq, 1], [:a]]]
        'invalid optional'  | { a: 1, b: 1 }       | []     | false | [[[:not_eq, 2], [:b]]]
        'append path'       | { a: 2, c: 3 }       | [1, 2] | false | [[[:not_eq, 1], [1, 2, :a]]]
        'valid mand+extra'  | { a: 1, c: 3 }       | []     | true  | { a: 1, c: 3 }
        'valid mand+opt'    | { a: 1, b: 2 }       | []     | true  | { a: 1, b: 2 }
        'extra key'         | { a: 1, b: 2, c: 3 } | []     | true  | { a: 1, b: 2, c: 3 }
      end

      with_them do
        subject do
          C.hash(
            full:      C.rule(error: :too_small) { _1.count >= 2 },
            mandatory: { a: C.eq(1) },
            optional:  { b: C.eq(2) }
          ).call value, path, value
        end

        it('has the expected result type') { expect(subject.success?).to eq success? }

        it 'has the expected result content' do
          expect(subject.either(ITSELF, ITSELF)).to eq result_contents
        end
      end
    end
  end

  describe :and do
    where :case_name, :value, :success?, :result_contents do
      'invalid left'  | 11 | false | [[:not_even, []]]
      'invalid right' | 6  | false | [[[:not_gt, 10], []]]
      'invalid both'  | 7  | false | [[:not_even, []], [[:not_gt, 10], []]]
      'valid both'    | 12 | true  | 12
    end

    with_them do
      subject { (C.rule(error: :not_even) { _1.even? } & C.gt(10)).call value, [], value }

      it('has the expected result type') { expect(subject.success?).to eq success? }

      it 'has the expected result content' do
        expect(subject.either(ITSELF, ITSELF)).to eq result_contents
      end
    end

    it 'propagates the same value to left and right validators' do
      result = (C.typed(T::Coercible::String) & C.gt(5)).call 6, [], 6
      expect(result).to be_success
      expect(result.value!).to eq 6
    end

    it 'succeeds with the right value' do
      result = (C.gt(5) & C.typed(T::Coercible::String)).call 6, [], 6
      expect(result).to be_success
      expect(result.value!).to eq '6'
    end
  end

  describe :then do
    where :case_name, :value, :success?, :result_contents do
      'invalid left'  | 11   | false | [[:not_even, []]]
      'invalid right' | 6    | false | [[[:not_gt, 10], []]]
      'invalid both'  | 7    | false | [[:not_even, []]]
      'valid both'    | 12   | true  | 12
    end

    with_them do
      subject { (C.rule(error: :not_even) { _1.even? } > C.gt(10)).call value, [], value }

      it('has the expected result type') { expect(subject.success?).to eq success? }

      it 'has the expected result content' do
        expect(subject.either(ITSELF, ITSELF)).to eq result_contents
      end
    end

    it 'propagates left success value to the right validator' do
      result = (C.typed(T::Coercible::Integer) > C.gt(10)).call '6', [], '6'
      expect(result).to be_failure
      expect(result.failure).to eq [[[:not_gt, 10], []]]
    end

    it 'succeeds with the right value' do
      result = (C.gt(5) > C.typed(T::Coercible::String)).call 6, [], 6
      expect(result).to be_success
      expect(result.value!).to eq '6'
    end
  end

  describe :rule do
    where :case_name, :predicate,                                         :success? do
      '0-arity false' | -> { false }                                           | false
      '0-arity true'  | -> { true }                                            | true
      '1-arity false' | -> { _1.even? }                                        | false
      '1-arity true'  | -> { _1.odd? }                                         | true
      '2-arity false' | -> { _1.odd? && _2.include?(:htap) }                   | false
      '2-arity true'  | -> { _1.odd? && _2.include?(:path) }                   | true
      '3-arity false' | -> { _1.odd? && _2.include?(:path) && _3.key?(:htap) } | false
      '3-arity false' | -> { _1.odd? && _2.include?(:path) && _3.key?(:path) } | true
    end

    with_them do
      subject { C.rule(error: :fail, &predicate).call 1, [:path], { path: 1 } }

      it('has the expected result type') { expect(subject.success?).to eq success? }

      it 'has the expected result content' do
        result_contents = success? ? 1 : [[:fail, [:path]]]
        expect(subject.either(ITSELF, ITSELF)).to eq result_contents
      end
    end

    it 'rejects blocks of arity > 3' do
      expect { C.rule(error: 0) { |_a, _b, _c, _d| true }.call true, [], true }.to raise_error
    end
  end

  describe 'prefab predicates' do
    where :case_name, :predicate,   :value, :success?, :result_contents do
      'present: nil'              | C.present         | nil   | false | [[:absent, []]]
      'present: not nil'          | C.present         | 1     | true  | 1
      'absent: not nil'           | C.absent          | 1     | false | [[:present, []]]
      'absent: nil'               | C.absent          | nil   | true  | nil
      'gt: < min'                 | C.gt(10)          | 9     | false | [[[:not_gt, 10], []]]
      'gt: = min'                 | C.gt(10)          | 10    | false | [[[:not_gt, 10], []]]
      'gt: > min'                 | C.gt(10)          | 11    | true  | 11
      'gteq: < min'               | C.gteq(10)        | 9     | false | [[[:not_gteq, 10], []]]
      'gteq: = min'               | C.gteq(10)        | 10    | true  | 10
      'gteq: > min'               | C.gteq(10)        | 11    | true  | 11
      'lt: < max'                 | C.lt(10)          | 9     | true  | 9
      'lt: = max'                 | C.lt(10)          | 10    | false | [[[:not_lt, 10], []]]
      'lt: > max'                 | C.lt(10)          | 11    | false | [[[:not_lt, 10], []]]
      'lteq: < max'               | C.lteq(10)        | 9     | true  | 9
      'lteq: = max'               | C.lteq(10)        | 10    | true  | 10
      'lteq: > max'               | C.lteq(10)        | 11    | false | [[[:not_lteq, 10], []]]
      'eq: != val'                | C.eq(10)               | 9     | false | [[[:not_eq, 10], []]]
      'eq: = val'                 | C.eq(10)               | 10    | true  | 10
      'neq: = val'                | C.neq(10)              | 10    | false | [[[:eq, 10], []]]
      'neq: != val'               | C.neq(10)              | 9     | true  | 9
      'included_in: not in set'   | C.included_in(1..10)   | 11    | false | [[[:not_included_in, 1..10], []]]
      'included_in: in set'       | C.included_in(1..10)   | 10    | true  | 10
      'excluded_from: in set'     | C.excluded_from(1..10) | 10    | false | [[[:included_in, 1..10], []]]
      'excluded_from: not in set' | C.excluded_from(1..10) | 11    | true  | 11
      'matching: not matching'    | C.matching(/abc/)      | 'cba' | false | [[[:not_matching, /abc/], []]]
      'matching: matching'        | C.matching(/abc/)      | 'abc' | true  | 'abc'
    end

    with_them do
      subject { predicate.call value, [], value }

      it('has the expected result type') { expect(subject.success?).to eq success? }

      it 'has the expected result content' do
        expect(subject.either(ITSELF, ITSELF)).to eq result_contents
      end
    end
  end
end
