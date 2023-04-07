require "test_helper"

class ModelTest < ActiveSupport::TestCase
  class Foo < ActiveRecord::Base
    include ExclusiveArc::Model
    exclusive_arc(
      bar: [:baz, :bizz],
      buzz: [:bing, :bong]
    )
    exclusive_arc :one, %i[two three four]
  end

  test "it can register exclusive arcs and inherent relationships" do
    assert_equal(
      [
        {bar: %i[baz bizz]},
        {buzz: %i[bing bong]},
        {one: %i[two three four]}
      ],
      Foo.exclusive_arcs
    )
    assert_equal 7, Foo.reflections.size
    assert_equal(
      true,
      Foo.reflections.values.all? do |reflection|
        reflection.is_a?(ActiveRecord::Reflection::BelongsToReflection) &&
          reflection.options[:optional]
      end
    )
  end
end
