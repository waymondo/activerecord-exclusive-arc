module ExclusiveArc
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :exclusive_arcs, default: []
      delegate :exclusive_arcs, to: :class
    end

    class_methods do
      def exclusive_arc(*arcs)
        arcs = arcs[0].is_a?(Hash) ? arcs[0] : {arcs[0] => arcs[1]}
        arcs.each do |(name, options)|
          exclusive_arcs << {name => options}

          options.each do |option|
            belongs_to option, optional: true
          end

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              @name ||= (#{options.join(" || ")})
            end
          RUBY
        end

        validate :validate_exclusive_arcs
      end
    end

    private

    def validate_exclusive_arcs
      exclusive_arcs.each do |(arc, options)|
        errors.add(arc, :arc_not_exclusive) unless options.count { |option| !!option } == 1
      end
    end
  end
end
