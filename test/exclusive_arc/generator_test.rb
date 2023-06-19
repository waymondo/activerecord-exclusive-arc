require "test_helper"

class GeneratorTest < Rails::Generators::TestCase
  tests ExclusiveArcGenerator
  TMP_DIR = File.expand_path("../../tmp/generator", __dir__)
  destination TMP_DIR

  def setup
    prepare_destination
    %w[government comment].each do |model|
      model_path = File.join(TMP_DIR, "app", "models", "#{model}.rb")
      FileUtils.mkdir_p(File.dirname(model_path))
      File.write(
        model_path,
        <<~RAW
          class #{model.classify} < ActiveRecord::Base
          end
        RAW
      )
    end
  end
  test "running generator twice updates model declaration" do
    run_generator %w[Comment commentable comment post]
    assert_migration "db/migrate/comment_commentable_exclusive_arc_comment_post.rb" do |migration|
      assert_match(/add_reference :comments, :comment, foreign_key: true, index:/, migration)
      assert_match(/add_check_constraint\(\n(\s*):comments/, migration)
      assert_match(/\(CASE(.*)\) = 1/, migration)
    end
    assert_file "app/models/comment.rb", /include ExclusiveArc::Model/
    assert_file "app/models/comment.rb", /has_exclusive_arc :commentable, \[:comment, :post\]/
    run_generator %w[Comment commentable comment post page]
    assert_file "app/models/comment.rb", /include ExclusiveArc::Model/
    assert_file "app/models/comment.rb", /has_exclusive_arc :commentable, \[:comment, :post, :page\]/
    assert_file "app/models/comment.rb" do |file|
      refute_match(/has_exclusive_arc :commentable, \[:comment, ::post\]/, file)
    end
  end

  test "it infers non traditional foreign key and builds appropriate migration" do
    city_foreign_key = Government.reflections["city"].foreign_key
    Government.reflections["city"].instance_variable_set(:@foreign_key, "foo_id")
    run_generator %w[Government region city county state]
    assert_migration "db/migrate/government_region_exclusive_arc_city_county_state.rb" do |migration|
      assert_match(/add_column :governments, :foo_id/, migration)
      assert_match(/add_foreign_key :governments, :cities, column: :foo_id/, migration)
      assert_match(/add_index :governments, :foo_id, where: "foo_id IS NOT NULL"/, migration)
      assert_match(/CASE WHEN foo_id IS NULL/, migration)
    end
    Government.reflections["city"].instance_variable_set(:@foreign_key, city_foreign_key)
  end

  test "it does not add reference when column already exists" do
    Government.stub(:column_names, %w[id name city_id]) do
      run_generator %w[Government region city county state]
      assert_migration "db/migrate/government_region_exclusive_arc_city_county_state.rb" do |migration|
        assert_match(/add_reference :governments, :county/, migration)
        assert_match(/add_reference :governments, :state/, migration)
        refute_match(/add_reference :governments, :city/, migration)
      end
    end
  end

  test "running with existing check constraint removes and re-adds" do
    run_generator %w[Comment commentable comment post]
    assert_migration "db/migrate/comment_commentable_exclusive_arc_comment_post.rb" do |migration|
      assert_match(/add_reference :comments, :comment/, migration)
      refute_match(/add_reference :comments, :post/, migration)
      assert_match(/remove_check_constraint\(\n(\s*):comments/, migration)
      assert_match(/add_check_constraint\(\n(\s*):comments/, migration)
    end
  end

  test "it generates an optional exclusive arc migration and model configuration" do
    run_generator ["Government", "region", "city", "county", "state", "--optional"]
    assert_migration "db/migrate/government_region_exclusive_arc_city_county_state.rb" do |migration|
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
    assert_migration "db/migrate/government_region_exclusive_arc_city_county_state.rb" do |migration|
      refute_match(/foreign_key: true/, migration)
    end
  end

  test "it can opt out of foreign key indexes" do
    run_generator ["Government", "region", "city", "county", "state", "--skip-foreign-key-indexes"]
    assert_migration "db/migrate/government_region_exclusive_arc_city_county_state.rb" do |migration|
      refute_match(/index:/, migration)
    end
  end

  test "it can opt out of check constraint" do
    run_generator ["Government", "region", "city", "county", "state", "--skip-check-constraint"]
    assert_migration "db/migrate/government_region_exclusive_arc_city_county_state.rb" do |migration|
      refute_match(/add_check_constraint/, migration)
    end
  end
end
