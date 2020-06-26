# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # This cop looks for all? / any? / none? / one? calls where the block
      # has a single statement and === has been invoked on the receiver so the
      # === argument can be used as the predicate method argument.
      #
      # @example
      #   # bad
      #   [1, 2, 3].any? { |e| Set[1, 2, 3] === e }
      #
      #   [1, 2, 3].none? do |e|
      #     e === Integer
      #   end
      #
      #   # good
      #   [1, 2, 3].any?(Set[1, 2, 3])
      #
      #   [1, 2, 3].none?(Integer)
      class PatternArgument < Cop
        include RangeHelp
        extend TargetRubyVersion

        minimum_target_ruby_version 2.5

        MSG = 'Pass `%<pattern>s` as an argument to `%<method>s` instead of a block.'

        def_node_matcher :pattern_as_parameter_candidate?, <<~PATTERN
          (block $({send csend} _ {:all? :any? :none? :one?}) $_ $_)
        PATTERN

        # rubocop:disable Metrics/MethodLength
        def on_block(node)
          pattern_as_parameter_candidate?(node) do |method, args, body|
            return unless body.respond_to?(:method?) && body.method?(:===)
            return unless args.size == 1

            receiver = body.receiver
            pattern = if receiver.begin_type? || receiver.send_type?
                        receiver
                      elsif body.send_type?
                        body.arguments.first
                      else
                        return
                      end

            add_offense(node, location: method.loc.selector,
                              message: format(MSG, method: method.method_name,
                                                   pattern: pattern.source))
          end
        end
        # rubocop:enable Metrics/MethodLength

        def autocorrect(node)
          lambda do |corrector|
            return unless node.body.method?(:===)

            replacement = pattern(node.body.arguments.first, node.body.receiver)
            corrector.replace(block_range_with_space(node), "(#{replacement.source})")
          end
        end

        private

        def pattern(arg, receiver)
          if arg.regexp_type? || arg.int_type? || (arg.send_type? && !arg.arguments?)
            arg
          elsif receiver.begin_type? && (range = receiver.children.find(&:range_type?))
            range
          else
            receiver
          end
        end

        def block_range_with_space(node)
          block_range = range_between(node.loc.begin.begin_pos, node.loc.end.end_pos)
          range_with_surrounding_space(range: block_range, side: :left)
        end
      end
    end
  end
end
