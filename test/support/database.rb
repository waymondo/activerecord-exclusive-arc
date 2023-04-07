def truncate_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.execute("TRUNCATE #{table} RESTART IDENTITY CASCADE")
  end
end

ActiveRecord::Base.connection.tables.each do |table|
  next unless ActiveRecord::Base.connection.table_exists?(table)

  ActiveRecord::Base.connection.drop_table(table, force: :cascade)
end

ActiveRecord::Schema.define do
  create_table :governments do |t|
    t.string :name
    t.bigint :city_id
    t.bigint :county_id
    t.bigint :state_id
    t.check_constraint(
      <<~SQL
        (
          (city_id IS NOT NULL)::integer +
          (county_id IS NOT NULL)::integer +
          (state_id IS NOT NULL)::integer
        ) = 1
      SQL
    )
  end

  create_table :cities do |t|
    t.string :name
  end

  create_table :counties do |t|
    t.string :name
  end

  create_table :states do |t|
    t.string :name
  end
end

class Government < ActiveRecord::Base
  include ExclusiveArc::Model
  exclusive_arc(
    region: %i[city county state]
  )
end

class City < ActiveRecord::Base
  has_many :geometries, dependent: :destroy
end

class County < ActiveRecord::Base
  has_many :geometries, dependent: :destroy
end

class State < ActiveRecord::Base
  has_many :geometries, dependent: :destroy
end
