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
  has_exclusive_arc :commentable, [:comment, :post]
end

def migrate_exclusive_arc(args)
  tmp_dir = File.expand_path("../../tmp", __dir__)
  FileUtils.rm_f Dir.glob("#{tmp_dir}/**/*")
  Rails::Generators.invoke("exclusive_arc", args + ["--quiet"], destination_root: tmp_dir)
  Dir[File.join(tmp_dir, "db/migrate/*.rb")].sort.each { |file| require file }
  targets = args[2..]
  (
    [args[0].delete(":").classify, args[1].classify, "ExclusiveArc"] |
    targets.map(&:classify)
  ).join.constantize.migrate(:up)
end

migrate_exclusive_arc(%w[Government region city county state])
