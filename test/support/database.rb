CONNECTION = ActiveRecord::Base.connection

CONNECTION.tables.each do |table|
  next unless CONNECTION.table_exists?(table)

  CONNECTION.drop_table(table, force: :cascade)
end

SUPPORTS_UUID = ENV["DATABASE_ADAPTER"] == "postgres"

ActiveRecord::Schema.define do
  if SUPPORTS_UUID
    create_table :cities, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name
    end
  else
    create_table :cities do |t|
      t.string :name
    end
  end

  create_table :counties do |t|
    t.string :name
  end

  create_table :states do |t|
    t.string :name
  end

  create_table :governments do |t|
    t.string :name
    if SUPPORTS_UUID
      t.references :city, type: :uuid, foreign_key: true
    else
      t.references :city, foreign_key: true
    end
    t.references :county, foreign_key: true
    t.references :state, foreign_key: true
    t.check_constraint(
      "(CASE WHEN city_id IS NULL THEN 0 ELSE 1 END + CASE WHEN county_id IS NULL THEN 0 ELSE 1 END + CASE WHEN state_id IS NULL THEN 0 ELSE 1 END) = 1",
      name: "region"
    )
  end

  create_table :posts

  create_table :comments do |t|
    t.bigint :post_id
    t.check_constraint(
      "(CASE WHEN post_id IS NULL THEN 0 ELSE 1 END) = 1",
      name: "commentable"
    )
  end
end

class Government < ActiveRecord::Base
  belongs_to :city, -> { where.not(name: nil) }, optional: true
  include ExclusiveArc::Model
  has_exclusive_arc(:region, %i[city county state])
end

class City < ActiveRecord::Base
  has_many :governments, dependent: :destroy
end

class County < ActiveRecord::Base
  has_many :governments, dependent: :destroy
end

class State < ActiveRecord::Base
  has_many :governments, dependent: :destroy
end

class Comment < ActiveRecord::Base
  has_many :comments
end

class Post < ActiveRecord::Base
  include ExclusiveArc::Model
  has_many :comments
  has_exclusive_arc :commentable, %i[comment post]
end

class TestMigration < ActiveRecord::Migration[ActiveRecord::Migration.current_version]
  def change
    add_reference :governments, :city, type: :uuid, foreign_key: true, index: {where: "city_id IS NOT NULL"}
    add_reference :governments, :county, foreign_key: true, index: {where: "county_id IS NOT NULL"}
    add_reference :governments, :state, foreign_key: true, index: {where: "state_id IS NOT NULL"}
    add_check_constraint(
      :governments,
      "(CASE WHEN city_id IS NULL THEN 0 ELSE 1 END + CASE WHEN county_id IS NULL THEN 0 ELSE 1 END + CASE WHEN state_id IS NULL THEN 0 ELSE 1 END) = 1",
      name: "region"
    )
  end
end
