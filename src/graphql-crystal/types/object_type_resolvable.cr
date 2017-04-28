module GraphQL
  module ObjectType
    module Resolvable
      alias ArgumentsType = Array(GraphQL::Language::Field)
      alias ReturnType = String | Int32 | Float64 | Nil | Bool | Array(ReturnType) | Hash(String, ReturnType)

      def resolve(fields : ArgumentsType, obj = nil)
        validate_fields_and_arguments(fields)

        fields.reduce(nil) do |hash, field|
          pair = { field.name => resolve(field, obj).as(ReturnType) }
          hash ? hash.merge(pair) : pair
        end.as(ReturnType)
      end

      def resolve(field : GraphQL::Language::Field, obj = nil)
        entity = obj && obj.responds_to?(:resolve_field) ? obj.resolve_field(
                   field.name,
                   arguments_array_to_hash(field.arguments)
                 ) : resolve_field(
                       field.name,
                       arguments_array_to_hash(field.arguments)
                     )
        # this nicely works with extended modules,
        # thereby making them real interfaces in
        # crystals type system
        field_type = self.fields[field.name][:type]
        selections = field.selections.compact_map { |f| f if f.is_a?(GraphQL::Language::Field) }
#        selections = field.selections.select(&.is_a?(GraphQL::Language::Field)).map(&.as(GraphQL::Language::Field))
        result = if field_type.responds_to? :resolve
                   field_type.resolve(selections, entity)
                 else
                   entity
                 end.as(ReturnType)
        result
      end

      private def arguments_array_to_hash(arguments)
        arguments.reduce(nil) do |memo, arg|
          field_pair = {arg.name => arg.value}
          memo ? memo.merge(field_pair) : field_pair
        end
      end
      #
      # Validate the fields and arguments of this QueryField
      # against the definition.
      # TODO: don't raise on the first error but collect them
      #
      def validate_fields_and_arguments(fields)
        allowed_field_names = self.fields.keys.map(&.to_s).to_a
        requested_field_names = fields.map(&.name)
        if (non_existent = requested_field_names - allowed_field_names).any?
          raise "unknown fields: #{non_existent.join(", ")}"
        end
        fields.each do |field|
          allowed_arguments = self.fields[field.name][:args] || NamedTuple.new
          field.arguments.each do |arg|
            if !(defined_type_for_field = allowed_arguments[arg.name]?)
              raise "#{arg.name} isn't allowed for queries on the #{field.name} field"
            elsif !defined_type_for_field.not_nil!.accepts?(arg.value)
              raise %{argument "#{arg.name}" is expected to be of Type: "#{defined_type_for_field}", \
                                                                  "#{arg.value}" has been rejected}
            end
          end
        end
      end
    end
  end
end