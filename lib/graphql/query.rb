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
  def initialize(schema, query_string, context: nil, variables: nil, debug: false, validate: true, operation_name: nil)
    @schema = schema
    @debug = debug
    if context
      warn("Initializing a Query with context is deprecated, pass the context to `execute` instead.")
      @provided_context = context
    end
    @validate = validate
    @operation_name = operation_name
    @fragments = {}
    @operations = {}
    if variables
      warn("Initializing a Query with variables is deprecated, pass the context to `execute` instead.")
      @provided_variables = variables
    else
      @provided_variables = {}
    end
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
    warn("Query#result is deprecated, use Schema#execute instead")
    @result ||= execute(
      variables: @provided_variables,
      context: @provided_context,
      operation_name: @operation_name)
  end

  # Execute the query string with the provided variables & context
  def execute(variables: {}, context: nil, operation_name: nil)
    if @validate && validation_errors.any?
      return { "errors" => validation_errors }
    end

    query_run = GraphQL::Query::Run.new(
      self,
      context: context,
      variables: variables,
      operation_name: operation_name,
    )
    GraphQL::Query::Executor.new(query_run).result
  end


  # Errors as a result of static validation
  # @return [Array<Hash>] Error hashes with `message`, `line` and `column`.
  def validation_errors
    @validation_errors ||= schema.static_validator.validate(document)
  end
end
require 'graphql/query/arguments'
require 'graphql/query/base_execution'
require 'graphql/query/context'
require 'graphql/query/directive_chain'
require 'graphql/query/executor'
require 'graphql/query/literal_input'
require 'graphql/query/run'
require 'graphql/query/serial_execution'
require 'graphql/query/type_resolver'
require 'graphql/query/variables'
