def truncate_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.execute("TRUNCATE #{table} RESTART IDENTITY CASCADE")
  end
end

ActiveRecord::Base.connection.tables.each do |table|
  next unless ActiveRecord::Base.connection.table_exists?(table)

  ActiveRecord::Base.connection.drop_table(table, force: :cascade)
end

SUPPORTS_UUID = ENV["DATABASE_ADAPTER"] != "sqlite3"

ActiveRecord::Schema.define do
  create_table :governments do |t|
    t.string :name
  end

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
end

class Government < ActiveRecord::Base
  include ExclusiveArc::Model
  has_exclusive_arc(:region, %i[city county state])
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

def migrate_exclusive_arc(args)
  tmp_dir = File.expand_path("../../tmp", __dir__)
  FileUtils.rm_f Dir.glob("#{tmp_dir}/**/*")
  Rails::Generators.invoke("exclusive_arc", args + ["--quiet"], destination_root: tmp_dir)
  Dir[File.join(tmp_dir, "db/migrate/*.rb")].sort.each { |file| require file }
  [args[0].delete(":").classify, args[1].classify, "ExclusiveArc"].join.constantize.migrate(:up)
end

migrate_exclusive_arc(%w[Government region city county state])
