class GraphQL::Query
  class OperationNameMissingError < StandardError
    def initialize(names)
      msg = "You must provide an operation name from: #{names.join(", ")}"
      super(msg)
    end
  end

  class VariableValidationError < GraphQL::ExecutionError
    def initialize(variable_ast, type, reason)
      msg = "Variable #{variable_ast.name} of type #{type} #{reason}"
      super(msg)
      self.ast_node = variable_ast
    end
  end

  class VariableMissingError < VariableValidationError
    def initialize(variable_ast, type)
      super(variable_ast, type, "can't be null")
    end
  end

  # If a resolve function returns `GraphQL::Query::DEFAULT_RESOLVE`,
  # The executor will send the field's name to the target object
  # and use the result.
  DEFAULT_RESOLVE = :__default_resolve
  attr_reader :schema, :document, :context, :fragments, :operations, :debug

  # Prepare query `query_string` on `schema`
  # @param schema [GraphQL::Schema]
  # @param query_string [String]
  # @param context [#[]] an arbitrary hash of values which you can access in {GraphQL::Field#resolve}
  # @param variables [Hash] values for `$variables` in the query
  # @param debug [Boolean] if true, errors are raised, if false, errors are put in the `errors` key
  # @param validate [Boolean] if true, `query_string` will be validated with {StaticValidation::Validator}
  # @param operation_name [String] if the query string contains many operations, this is the one which should be executed
  def initialize(schema, query_string, context: nil, variables: {}, debug: false, validate: true, operation_name: nil)
    @schema = schema
    @debug = debug
    @provided_context = context
    @validate = validate
    @operation_name = operation_name
    @fragments = {}
    @operations = {}
    @provided_variables = variables
    @document = GraphQL.parse(query_string)
    @document.parts.each do |part|
      if part.is_a?(GraphQL::Language::Nodes::FragmentDefinition)
        @fragments[part.name] = part
      elsif part.is_a?(GraphQL::Language::Nodes::OperationDefinition)
        @operations[part.name] = part
      end
    end
  end

  # Get the result for this query, executing it once
  def result
    if @validate && validation_errors.any?
      return { "errors" => validation_errors }
    end

    @result ||= execute(
      variables: @provided_variables,
      context: @provided_context,
      operation_name: @operation_name)
  end

  # Execute the query string with the provided variables & context
  def execute(variables:, context:, operation_name:)
    proxy = Proxy.new(
      self,
      context: context,
      variables: variables,
      operation_name: operation_name,
    )
    GraphQL::Query::Executor.new(proxy).result
  end


  # Errors as a result of static validation
  # @return [Array<Hash>] Error hashes with `message`, `line` and `column`.
  def validation_errors
    @validation_errors ||= schema.static_validator.validate(document)
  end

  private
  class Proxy
    extend Forwardable
    def initialize(query, context:, variables:, operation_name:)
      @query = query
      @operation_name = operation_name
      @provided_context = context
      @provided_variables = variables
    end


    # Determine the values for variables of this query, using default values
    # if a value isn't provided at runtime.
    #
    # Raises if a non-null variable isn't provided at runtime.
    # @return [GraphQL::Query::Variables] Variables to apply to this query
    def variables
      @variables ||= GraphQL::Query::Variables.new(
        @query.schema,
        @selected_operation.variables,
        @provided_variables
      )
    end

    def context
      @context ||= Context.new(query: self, values: @provided_context)
    end

    # This is the operation to run for this query.
    # If more than one operation is present, it must be named at runtime.
    # @return [GraphQL::Language::Nodes::OperationDefinition, nil]
    def selected_operation
      @selected_operation ||= find_operation(@query.operations, @operation_name)
    end

    def_delegators :@query, :operations, :fragments, :schema, :debug

    private

    def find_operation(operations, operation_name)
      if operations.length == 1
        operations.values.first
      elsif operations.length == 0
        nil
      elsif !operations.key?(operation_name)
        raise OperationNameMissingError, operations.keys
      else
        operations[operation_name]
      end
    end
  end
end
require 'graphql/query/arguments'
require 'graphql/query/base_execution'
require 'graphql/query/context'
require 'graphql/query/directive_chain'
require 'graphql/query/executor'
require 'graphql/query/literal_input'
require 'graphql/query/serial_execution'
require 'graphql/query/type_resolver'
require 'graphql/query/variables'
