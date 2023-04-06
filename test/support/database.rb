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
  create_table :tags do |t|
    t.string :name
    t.bigint :post_id, index: true
    t.bigint :comment_id, index: true
  end
end
