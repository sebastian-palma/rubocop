# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::PatternArgument, :config do
  context 'when using Ruby 2.5 or newer', :ruby25 do
    %w[all? any? none? one?].map { |method| [method, '^' * method.length] }.each do |method, arrows|
      describe method do
        context 'invoking === on another object within the block' do
          it 'registers an offense' do
            expect_offense(<<~RUBY)
            [1, 2, 3].#{method} { |e| Set[1, 2, 3] === e }
                      #{arrows} Pass `Set[1, 2, 3]` as an argument to `#{method}` instead of a block.
            RUBY
          end

          it 'auto-corrects' do
            autocorrection = autocorrect_source("[1, 2, 3].#{method} { |e| Set[1, 2, 3] === e }")
            expect(autocorrection).to eq("[1, 2, 3].#{method}(Set[1, 2, 3])")
          end
        end

        context 'invoking === on the current element' do
          it 'registers an offense' do
            expect_offense(<<~RUBY)
            ['foo', 'bar'].#{method} { |e| e === /foo/ }
                           #{arrows} Pass `/foo/` as an argument to `#{method}` instead of a block.
            RUBY
          end

          it 'auto-corrects' do
            autocorrection = autocorrect_source("['foo', 'bar'].#{method} { |e| e === /foo/ }")
            expect(autocorrection).to eq("['foo', 'bar'].#{method}(/foo/)")
          end
        end

        context 'invoking === on a range' do
          it 'registers an offense' do
            expect_offense(<<~RUBY)
            [1, 2, 3].#{method} { |e| (1..nil) === e }
                      #{arrows} Pass `(1..nil)` as an argument to `#{method}` instead of a block.
            RUBY
          end

          it 'auto-corrects' do
            autocorrection = autocorrect_source("[1, 2, 3].#{method} { |e| (1..nil) === e }")
            expect(autocorrection).to eq("[1, 2, 3].#{method}(1..nil)")
          end
        end

        context "invoking #{method} on an underscore variable" do
          it 'registers an offense' do
            expect_offense(<<~RUBY)
            _.#{method} { |e| Range::new(1, 10) === e }
              #{arrows} Pass `Range::new(1, 10)` as an argument to `#{method}` instead of a block.
            RUBY
          end

          it 'auto-corrects' do
            autocorrection = autocorrect_source("_.#{method} { |e| Range::new(1, 10) === e }")
            expect(autocorrection).to eq("_.#{method}(Range::new(1, 10))")
          end
        end

        context "invoking #{method} on a local variable" do
          it "registers an offense" do
            expect_offense(<<~RUBY)
            some_array.#{method} { |e| e === some_number }
                       #{arrows} Pass `some_number` as an argument to `#{method}` instead of a block.
            RUBY
          end

          it "auto-corrects" do
            autocorrection = autocorrect_source("some_array.#{method} { |e| e === some_number }")
            expect(autocorrection).to eq("some_array.#{method}(some_number)")
          end
        end

        context "chaining #{method} with a safe navigation operator" do
          it "registers an offense" do
            expect_offense(<<~RUBY)
            [1, 2, 3]&.#{method} { |e| Range.new(1, 10) === e }
                       #{arrows} Pass `Range.new(1, 10)` as an argument to `#{method}` instead of a block.
            RUBY
          end

          it "auto-corrects" do
            autocorrection = autocorrect_source("[1, 2, 3]&.#{method} { |e| Range.new(1, 10) === e }")
            expect(autocorrection).to eq("[1, 2, 3]&.#{method}(Range.new(1, 10))")
          end
        end

        context "registers an offense in a multiline block" do
          let(:source) do
            <<~RUBY
            [1, 2, 3].#{method} do |e|
              e === 42
            end
          RUBY
          end

          it "registers an offense" do
            expect_offense(<<~RUBY)
            [1, 2, 3].#{method} do |e|
                      #{arrows} Pass `42` as an argument to `#{method}` instead of a block.
              e === 42
            end
          RUBY
          end

          it "auto-corrects" do
            expect(autocorrect_source(source)).to eq(<<~RUBY)
            [1, 2, 3].#{method}(42)
            RUBY
          end
        end

        context "when using Ruby 2.6+", :ruby26 do
          it "using an endless range" do
            expect_offense(<<~RUBY)
            [1, 2, 3].#{method} { |e| (1..) === e }
                      #{arrows} Pass `(1..)` as an argument to `#{method}` instead of a block.
            RUBY
          end

          it "auto-corrects" do
            autocorrection = autocorrect_source("[1, 2, 3].#{method} { |e| (1..) === e }")
            expect(autocorrection).to eq("[1, 2, 3].#{method}(1..)")
          end
        end

        context "when using Ruby 2.7+", :ruby27 do
          it "using a beginless range" do
            expect_offense(<<~RUBY)
            [1, 2, 3].#{method} { |e| (...1) === e }
                      #{arrows} Pass `(...1)` as an argument to `#{method}` instead of a block.
            RUBY
          end

          it "auto-corrects" do
            autocorrection = autocorrect_source("[1, 2, 3].#{method} { |e| (...1) === e }")
            expect(autocorrection).to eq("[1, 2, 3].#{method}(...1)")
          end
        end

        it "accepts a block with methods other than ===" do
          expect_no_offenses(<<~RUBY)
          ["foo", "bar"].#{method} { |e| /foo/ =~ e }
          [1, 2, 3].#{method} { |e| e == 42 }
          many_integers.#{method} { |e| e >= some_different_number }
          [:foo, :bar, :foobar].#{method} { |e| e.kind_of(String) }
          [1, 2, 3].#{method} { |e| Prime.prime?(e) }
          RUBY
        end

        it "accepts a block with more than 1 expression in the body" do
          expect_no_offenses(<<~RUBY)
          ["foo", "bar"].#{method} { |e| 42 > 41 && /foo/ === e }
          [1, 2, 3].#{method} { |e| n = (Math::PI * e).fdiv(magic_number); n === e }
          ["foo", "bar"].#{method} do |e|
            e =~ /foo/ && 1 == 0
          end
          [{ foo: :foo, bar: :bar }, { foo: :bar, bar: :foo }].#{method} do |hash|
            foo, bar = hash.values_at(:foo, :bar)
            foo === bar
          end
        RUBY
        end

        it "accepts a block yielding multiple values" do
          expect_no_offenses("[[1, :one], [2, :two]].#{method} { |_, e| Symbol === e }")
          expect_no_offenses("[%w[fo_o o], %w[foo_bar bar]].#{method} { |e, f| /_\#{f}$/ === e }")
        end
      end
    end
  end

  context 'below Ruby 2.5', :ruby24 do
    it 'does not flag even if the pattern could be used as the predicate argument' do
      expect_no_offenses('[1, 2, 3].any? { |e| (1..10) === e }')
    end
  end
end
