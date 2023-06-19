module ExclusiveArc
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :exclusive_arcs, default: {}
      delegate :exclusive_arcs, to: :class
    end

    class_methods do
      def has_exclusive_arc(*args)
        arc = args[0]
        belong_tos = args[1]
        belong_tos.map do |option|
          next if reflections[option.to_s]

          belongs_to(option, optional: true)
          validate "validate_#{arc}".to_sym
        end

        exclusive_arcs[arc] = Definition.new(
          reflections: reflections.slice(*belong_tos.map(&:to_s)),
          options: args[2] || {}
        )

        belong_tos.each do |option|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{option}=(polymorphic)
              @#{arc} = nil unless @#{arc} == polymorphic
              super
            end
          RUBY
        end

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{arc}
            @#{arc} ||= (#{belong_tos.join(" || ")})
          end

          def #{arc}=(polymorphic)
            assign_exclusive_arc(:#{arc}, polymorphic)
            @#{arc} = polymorphic
          end

          def validate_#{arc}
            validate_exclusive_arc(:#{arc})
          end
        RUBY
      end
    end

    private

    def assign_exclusive_arc(arc, polymorphic)
      attributes = exclusive_arcs.fetch(arc).reflections.to_h do |name, reflection|
        [name, polymorphic.is_a?(reflection.klass) ? polymorphic : nil]
      end
      assign_attributes attributes
    end

    def validate_exclusive_arc(arc)
      definition = exclusive_arcs.fetch(arc)
      foreign_key_count = definition.reflections.keys.count { |name| !!public_send(name) }
      valid = definition.options[:optional] ? foreign_key_count.in?([0, 1]) : foreign_key_count == 1
      errors.add(arc, :arc_not_exclusive) unless valid
    end
  end
end
