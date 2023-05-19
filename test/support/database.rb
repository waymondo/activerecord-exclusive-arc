CONNECTION = ActiveRecord::Base.connection

def truncate_db
  CONNECTION.tables.each do |table|
    CONNECTION.execute("TRUNCATE #{table} RESTART IDENTITY CASCADE")
  end
end

CONNECTION.tables.each do |table|
  next unless CONNECTION.table_exists?(table)

  CONNECTION.drop_table(table, force: :cascade)
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

def migrate_exclusive_arc(args, direction = :up)
  tmp_dir = File.expand_path("../../tmp", __dir__)
  FileUtils.rm_f Dir.glob("#{tmp_dir}/**/*")
  Rails::Generators.invoke("exclusive_arc", args + ["--quiet"], destination_root: tmp_dir)
  Dir[File.join(tmp_dir, "db/migrate/*.rb")].sort.each { |file| require file }
  [args[0].delete(":").classify, args[1].classify, "ExclusiveArc"].join.constantize.migrate(direction)
end

migrate_exclusive_arc(%w[Government region city county state])
