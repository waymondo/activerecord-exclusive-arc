require "rails/generators"
require "rails/generators/active_record/migration/migration_generator"

class ExclusiveArcGenerator < ActiveRecord::Generators::Base
  source_root File.expand_path("templates", __dir__)
  desc "Adds an Exclusive Arc to an ActiveRecord model and generates the migration for it"

  argument :arguments, type: :array, default: [], banner: "arc belongs_to1 belongs_to2 ..."
  class_option :optional, type: :boolean, default: false, desc: "Exclusive arc is optional"
  class_option :skip_foreign_key_constraints, type: :boolean, default: false, desc: "Skip foreign key constraints"
  class_option :skip_foreign_key_indexes, type: :boolean, default: false, desc: "Skip foreign key partial indexes"
  class_option :skip_check_constraint, type: :boolean, default: false, desc: "Skip check constraint"

  Error = Class.new(StandardError)

  def initialize(*args)
    raise Error, "must supply a Model, arc, and at least two belong_tos" if args[0].size <= 3
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
      RB
    )
    gsub_file(
      model_file_path,
      /has_exclusive_arc :#{arc}(.*)$/,
      ""
    )
    inject_into_file(
      model_file_path,
      <<~RB,
        #{indents}has_exclusive_arc #{model_exclusive_arcs}
      RB
      after: "include ExclusiveArc::Model\n"
    )
  end

  no_tasks do
    def model_exclusive_arcs
      string = ":#{arc}, [#{belong_tos.map { |reference| ":#{reference}" }.join(", ")}]"
      string += ", optional: true" if options[:optional]
      string
    end

    def add_references
      belong_tos.map do |reference|
        add_reference(reference) unless column_exists?(reference)
      end.compact.join("\n")
    end

    def add_reference(reference)
      foreign_key = foreign_key_name(reference)
      type = reference_type(reference).downcase
      if foreign_key == "#{reference}_id"
        string = "    add_reference :#{table_name}, :#{reference}"
        string += ", type: :#{type}" unless /int/.match?(type)
        string += ", foreign_key: true" unless options[:skip_foreign_key_constraints]
        string += ", index: {where: \"#{foreign_key} IS NOT NULL\"}" unless options[:skip_foreign_key_indexes]
      else
        string = "    add_column :#{table_name}, :#{foreign_key}, :#{type}"
        unless options[:skip_foreign_key_constraints]
          referenced_table_name = reference_table_name(reference)
          string += "\n    add_foreign_key :#{table_name}, :#{referenced_table_name}, column: :#{foreign_key}"
        end
        unless options[:skip_foreign_key_indexes]
          string += "\n    add_index :#{table_name}, :#{foreign_key}, where: \"#{foreign_key} IS NOT NULL\""
        end
      end
      string
    end

    def migration_file_name
      "#{class_name.delete(":").underscore}_#{arc}_exclusive_arc_#{belong_tos.map(&:underscore).join("_")}.rb"
    end

    def migration_class_name
      (
        [class_name.delete(":").singularize, arc.classify, "ExclusiveArc"] |
        belong_tos.map(&:classify)
      ).join
    end

    def existing_check_constraint
      @existing_check_constraint ||=
        class_name.constantize.connection.check_constraints(class_name.constantize.table_name)
          .find { |constraint| constraint.name == arc }
    rescue
      nil
    end

    def reference_type(reference)
      klass = class_name.constantize.reflections[reference].klass
      klass.columns.find { |col| col.name == klass.primary_key }.sql_type
    rescue
      "bigint"
    end

    def reference_table_name(reference)
      class_name.constantize.reflections[reference].klass.table_name
    rescue
      reference.tableize
    end

    def column_exists?(reference)
      foreign_key = foreign_key_name(reference)
      class_name.constantize.column_names.include?(foreign_key)
    rescue
      false
    end

    def foreign_key_name(reference)
      class_name.constantize.reflections[reference].foreign_key
    rescue
      "#{reference}_id"
    end

    def remove_check_constraint
      return unless class_name.constantize.connection.supports_check_constraints?
      return if options[:skip_check_constraint]
      return unless existing_check_constraint&.expression

      <<-RUBY.chomp
    remove_check_constraint(
      :#{table_name},
      "#{existing_check_constraint.expression.squish}",
      name: "#{arc}"
    )
      RUBY
    end

    def add_check_constraint
      return unless class_name.constantize.connection.supports_check_constraints?
      return if options[:skip_check_constraint]
      <<-RUBY.chomp
    add_check_constraint(
      :#{table_name},
      "#{check_constraint}",
      name: "#{arc}"
    )
      RUBY
    end

    def check_constraint
      reference_checks = belong_tos.map do |reference|
        "CASE WHEN #{foreign_key_name(reference)} IS NULL THEN 0 ELSE 1 END"
      end
      condition = options[:optional] ? "<= 1" : "= 1"
      "(#{reference_checks.join(" + ")}) #{condition}"
    end

    def arc
      arguments[0]
    end

    def belong_tos
      @belong_tos ||= arguments.slice(1, arguments.length - 1)
    end

    def model_file_path
      File.join("app", "models", "#{file_path}.rb")
    end
  end
end
