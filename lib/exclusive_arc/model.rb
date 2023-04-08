module ExclusiveArc
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :exclusive_arcs, default: {}
      delegate :exclusive_arcs, to: :class
    end

    class_methods do
      def exclusive_arc(*args)
        arcs = args[0].is_a?(Hash) ? args[0] : {args[0] => args[1]}
        options = args[2] || {}
        arcs.each do |(name, belong_tos)|
          belong_tos.map { |option| belongs_to(option, optional: true) }
          exclusive_arcs[name] = Definition.new(
            reflections: reflections.slice(*belong_tos.map(&:to_s)),
            options: options
          )

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              #{belong_tos.join(" || ")}
            end

            def #{name}=(polymorphic)
              assign_exclusive_arc(:#{name}, polymorphic)
            end
          RUBY
        end

        validate :validate_exclusive_arcs
      end
    end

    private

    def assign_exclusive_arc(arc, polymorphic)
      exclusive_arcs.fetch(arc).reflections.each do |name, reflection|
        public_send("#{name}=", polymorphic.is_a?(reflection.klass) ? polymorphic : nil)
      end
    end

    def validate_exclusive_arcs
      exclusive_arcs.each do |(arc, definition)|
        foreign_key_count = definition.reflections.keys.count { |name| !!public_send(name) }
        valid = definition.options[:optional] ? foreign_key_count.in?([0, 1]) : foreign_key_count == 1
        errors.add(arc, :arc_not_exclusive) unless valid
      end
    end
  end
end
