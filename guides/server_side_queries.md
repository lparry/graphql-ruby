# Server-Side Queries

`GraphQL::QueryCache` allows you to load queries on the server, then invoke them by name in the client. This way, you an skip the overhead of parsing the same query over and over. Instead, run the _same_ query with _new_ variables & context.

## Caching Queries

Store queries in a query cache:

```ruby
MySchema.cache("
query getItem($id: Int!) {
  item(id: $id) {
    name,
    price,
    reviews(first: 3) {
      user { name }
      content
    }
  }
}
")
```

## Invoking stored queries

Invoke a query by passing its _operation name_, but not a query string.

```ruby
MySchema.execute(operation_name: "getItem", variables: {"id" => 3})
# {
#  "data" => {
#    "item" => { ... }
#   }
# }
```
