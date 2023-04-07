module ExclusiveArc
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :exclusive_arcs, default: {}
      delegate :exclusive_arcs, to: :class
    end

    class_methods do
      def exclusive_arc(*arcs)
        arcs = arcs[0].is_a?(Hash) ? arcs[0] : {arcs[0] => arcs[1]}

        arcs.each do |(name, options)|
          options.map { |option| belongs_to(option, optional: true) }
          exclusive_arcs[name] = reflections.slice(*options.map(&:to_s))

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              #{options.join(" || ")}
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
      exclusive_arcs[arc].each do |name, reflection|
        # TODO: handle polymorphic relationships where the same AR class is used
        public_send("#{name}=", polymorphic.is_a?(reflection.klass) ? polymorphic : nil)
      end
    end

    def validate_exclusive_arcs
      exclusive_arcs.each do |(arc, options)|
        errors.add(arc, :arc_not_exclusive) unless options.keys.count do |name|
          !!public_send(name)
        end == 1
      end
    end
  end
end
