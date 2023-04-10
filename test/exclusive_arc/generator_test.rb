require "test_helper"

class GeneratorTest < Rails::Generators::TestCase
  tests ExclusiveArcGenerator
  TMP_DIR = File.expand_path("../../tmp", __dir__)
  destination TMP_DIR

  def setup
    prepare_destination
    model_path = File.join(TMP_DIR, "app", "models", "government.rb")
    FileUtils.mkdir_p(File.dirname(model_path))
    File.write(
      model_path,
      <<~RAW
        class Government < ActiveRecord::Base
        end
      RAW
    )
  end

  test "it generates an exclusive arc migration and injects into model" do
    run_generator %w[Government region city county state]
    assert_migration "db/migrate/government_region_exclusive_arc.rb" do |migration|
      if SUPPORTS_UUID
        assert_match(/add_reference :governments, :city, type: :uuid, foreign_key: true, index:/, migration)
      else
        assert_match(/add_reference :governments, :city, foreign_key: true, index:/, migration)
      end
      assert_match(/add_reference :governments, :county, foreign_key: true, index:/, migration)
      assert_match(/add_reference :governments, :state, foreign_key: true, index:/, migration)
      assert_match(/add_check_constraint\(\n(\s*):governments/, migration)
      assert_match(/\(CASE(.*)\) = 1/, migration)
    end
    assert_file "app/models/government.rb", /include ExclusiveArc::Model/
    assert_file "app/models/government.rb", /has_exclusive_arc :region, \[:city, :county, :state\]/
  end

  test "it infers non traditional foreign key and builds appropriate migration" do
    city_foreign_key = Government.reflections["city"].foreign_key
    Government.reflections["city"].instance_variable_set(:@foreign_key, "foo_id")
    run_generator %w[Government region city county state]
    assert_migration "db/migrate/government_region_exclusive_arc.rb" do |migration|
      assert_match(/add_column :governments, :foo_id/, migration)
      assert_match(/add_foreign_key :governments, :cities, column: :foo_id/, migration)
      assert_match(/add_index :governments, :foo_id, where: "foo_id IS NOT NULL"/, migration)
      assert_match(/CASE WHEN foo_id IS NULL/, migration)
    end
    Government.reflections["city"].instance_variable_set(:@foreign_key, city_foreign_key)
  end

  test "it generates an optional exclusive arc migration and model configuration" do
    run_generator ["Government", "region", "city", "county", "state", "--optional"]
    assert_migration "db/migrate/government_region_exclusive_arc.rb" do |migration|
      assert_match(/\(CASE(.*)\) <= 1/, migration)
    end
    assert_file "app/models/government.rb", /has_exclusive_arc :region, \[:city, :county, :state\], optional: true/
  end

  test "it raises an error if generator not given enough arguments" do
    assert_raises(ExclusiveArcGenerator::Error) do
      run_generator %w[Government region city]
    end
  end

  test "it can opt out of foreign key constraints" do
    run_generator ["Government", "region", "city", "county", "state", "--skip-foreign-key-constraints"]
    assert_migration "db/migrate/government_region_exclusive_arc.rb" do |migration|
      refute_match(/foreign_key: true/, migration)
    end
  end

  test "it can opt out of foreign key indexes" do
    run_generator ["Government", "region", "city", "county", "state", "--skip-foreign-key-indexes"]
    assert_migration "db/migrate/government_region_exclusive_arc.rb" do |migration|
      refute_match(/index:/, migration)
    end
  end

  test "it can opt out of check constraint" do
    run_generator ["Government", "region", "city", "county", "state", "--skip-check-constraint"]
    assert_migration "db/migrate/government_region_exclusive_arc.rb" do |migration|
      refute_match(/add_check_constraint/, migration)
    end
  end
end
