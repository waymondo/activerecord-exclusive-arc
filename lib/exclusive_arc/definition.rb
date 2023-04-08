module ExclusiveArc
  class Definition
    attr_reader :reflections, :options

    def initialize(reflections:, options:)
      @reflections = reflections
      @options = options
    end
  end
end
