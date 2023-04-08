require "test_helper"

class ModelTest < ActiveSupport::TestCase
  class Foo < ActiveRecord::Base
    include ExclusiveArc::Model
    exclusive_arc(
      bar: [:baz, :bizz],
      buzz: [:bing, :bong]
    )
    exclusive_arc :one, %i[two three four], optional: true
  end

  test "it can register exclusive arcs and inherent relationships" do
    assert_equal(%i[bar buzz one], Foo.exclusive_arcs.keys)
    reflections =
      Foo.exclusive_arcs.values.map { |definition| definition.reflections }.map(&:values).flatten
    assert_equal 7, reflections.size
    assert_equal(
      true,
      reflections.all? do |reflection|
        reflection.is_a?(ActiveRecord::Reflection::BelongsToReflection) &&
          reflection.options[:optional]
      end
    )
    refute Foo.exclusive_arcs.fetch(:bar).options[:optional]
    assert Foo.exclusive_arcs.fetch(:one).options[:optional]
  end

  test "it can validate an exclusive arc" do
    city = City.create!(name: "Ithaca")
    county = County.create!(name: "Tompkins")
    government = Government.new
    refute government.valid?
    government.city = city
    assert government.valid?
    government.county = county
    assert_arc_not_exclusive(government)
    government.city = nil
    assert government.valid?
    government.save!
    government.county = nil
    assert_arc_not_exclusive(government)
  end

  test "it can validate an optional exclusive arc" do
    city = City.create!(name: "Ithaca")
    county = County.create!(name: "Tompkins")
    government = Government.new
    government.exclusive_arcs.fetch(:region).stub :options, {optional: true} do
      assert government.valid?
      government.city = city
      assert government.valid?
      government.county = county
      refute government.valid?
    end
  end

  test "it can assign and return polymorphic association" do
    county = County.create!(name: "Queens")
    state = State.create!(name: "New York")
    government = Government.create!(county: county)
    assert_equal county, government.region
    government.region = state
    assert_equal state, government.region
    assert_equal state, government.state
    assert_nil government.county
    government.state = nil
    government.county = county
    assert_equal county, government.region
    government.save!
  end

  test "bypassing callbacks raises check constraint error" do
    county = County.create!(name: "Queens")
    state = State.create!(name: "New York")
    government = Government.create!(county: county)
    assert_raises(ActiveRecord::StatementInvalid) do
      government.update_column(:state_id, state.id)
    end
  end

  private

  def assert_arc_not_exclusive(government)
    refute government.valid?
    assert_equal government.errors[:region].size, 1
    assert_raises(ActiveRecord::RecordInvalid) do
      government.save!
    end
  end
end
