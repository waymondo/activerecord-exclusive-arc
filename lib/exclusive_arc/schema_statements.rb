module ExclusiveArc
  module SchemaStatements
    def add_exclusive_arc(table_name, arc_name, references)
      references.each do |reference|
        # TODO: foreign key types?
        add_column table_name, reference
      end
      reference_checks = references.map do |reference|
        "(#{reference}_id IS NOT NULL)::integer"
      end
      add_check_constraint table_name, "(#{reference_checks.join(" + ")}) = 1", name: arc_name
    end
  end
end
