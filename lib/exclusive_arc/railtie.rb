module ExclusiveArc
  class Railtie < Rails::Railtie
    initializer "exclusive-arc.load" do
      ActiveSupport.on_load :active_record do
        ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, SchemaStatements)
      end
    end
  end
end
