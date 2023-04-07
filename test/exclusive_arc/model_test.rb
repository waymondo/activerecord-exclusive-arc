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
    assert_equal(
      true,
      Foo.reflections.values.all? do |reflection|
        reflection.is_a?(ActiveRecord::Reflection::BelongsToReflection) &&
          reflection.options[:optional]
      end
    )
  end

  test "it can validate an exclusive arc" do
    city = City.create!(name: "Ithaca")
    county = County.create!(name: "Tompkins")
    government = Government.new
    refute government.valid?
    government.city = city
    assert government.valid?
    government.county = county
    refute government.valid?
    assert_raises(ActiveRecord::RecordInvalid) do
      government.save!
    end
    government.city = nil
    assert government.valid?
    government.save!
    government.county = nil
    refute government.valid?
    assert_raises(ActiveRecord::RecordInvalid) do
      government.save!
    end
  end
end
