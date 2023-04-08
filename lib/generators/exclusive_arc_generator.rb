require "rails/generators"
require "rails/generators/active_record/migration/migration_generator"

class ExclusiveArcGenerator < ActiveRecord::Generators::Base
  source_root File.expand_path("templates", __dir__)
  desc "Adds an exclusive arc to a model and generates the necessary migration"

  argument :arguments, type: :array, default: [], banner: "arc reference1 reference2 ..."
  class_option :skip_foreign_key_constraints, type: :boolean, default: false
  class_option :skip_foreign_key_indexes, type: :boolean, default: false
  class_option :skip_check_constraint, type: :boolean, default: false

  Error = Class.new(StandardError)

  def initialize(*args)
    raise Error, "must supply an arc and at least two references" if args[0].size <= 3
    super
  end

  def create_exclusive_arc_migration
    migration_template(
      "migration.rb.erb",
      "db/migrate/#{migration_file_name}"
    )
  end

  def inject_exclusive_arc_into_model
    indents = "  " * (class_name.scan("::").count + 1)
    inject_into_class(
      model_file_path,
      class_name.demodulize,
      <<~RB
        #{indents}include ExclusiveArc::Model
        #{indents}exclusive_arc #{model_exclusive_arcs}
      RB
    )
  end

  no_tasks do
    def model_exclusive_arcs
      "#{arc}: [#{references.map { |reference| ":#{reference}" }.join(", ")}]"
    end

    def add_reference(reference)
      string = "add_reference :#{table_name}, :#{reference}"
      type = reference_type(reference)
      string += ", type: :#{type}" unless /int/.match?(type.downcase)
      string += ", foreign_key: true" unless options[:skip_foreign_key_constraints]
      # TODO: this
      string += ", index: {where: \"#{reference}_id IS NOT NULL\"}" unless options[:skip_foreign_key_indexes]
      string
    end

    def migration_file_name
      "#{class_name.delete(":").underscore}_#{arc}_exclusive_arc.rb"
    end

    def migration_class_name
      [class_name.delete(":").singularize, arc.classify, "ExclusiveArc"].join
    end

    def reference_type(reference)
      klass = reference.singularize.classify.constantize
      klass.columns.find { |col| col.name == klass.primary_key }.sql_type
    rescue
      "bigint"
    end

    def check_constraint
      reference_checks = references.map do |reference|
        "CASE WHEN #{reference}_id IS NULL THEN 0 ELSE 1 END"
      end
      "(#{reference_checks.join(" + ")}) = 1"
    end

    def arc
      arguments[0]
    end

    def references
      @references ||= arguments.slice(1, arguments.length - 1)
    end

    def model_file_path
      File.join("app", "models", "#{file_path}.rb")
    end
  end
end
