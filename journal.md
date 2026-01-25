# Rails Mastery Journal

## Day 1
For the assignment here, I generated a test app and started it as follows using: 

```ruby
rails new test_app
rails g controller pages home
bin/dev
```

I then issued a curl command to hit the app:

```sh
curl http://localhost:3000/pages/home
```

What I expected was:

1. Rails' ActionDispatch receives the HTTP request (`GET /pages/home`)
2. ActionDispatch uses the routing in `config/routes.rb` to identify a match
3. It finds the line `get "pages/home"` which matches a GET request to "/pages/home"
4. Using this, it identifies the `pages` controller (`PagesController`) and the action `#home`
5. It then calls this method which is empty
6. By default, Rails will render the view in the corresponding `app/views/pages` folder named `home.html.erb`

What I see in the logs:

```sh
Started GET "/pages/home" for ::1 at 2026-01-22 17:50:39 -0500
   (0.2ms)  CREATE TABLE "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY) /*application='TestApp'*/
   (0.1ms)  CREATE TABLE "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL) /*application='TestApp'*/
  ActiveRecord::SchemaMigration Load (0.1ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC /*application='TestApp'*/
Processing by PagesController#home as */*
  Rendering layout layouts/application.html.erb
  Rendering pages/home.html.erb within layouts/application
  Rendered pages/home.html.erb within layouts/application (Duration: 0.1ms | GC: 0.0ms)
  Rendered layout layouts/application.html.erb (Duration: 5.2ms | GC: 1.0ms)
Completed 200 OK in 26ms (Views: 8.5ms | ActiveRecord: 0.0ms (0 queries, 0 cached) | GC: 3.1ms)
```

Starting line-by-line:

```
Started GET "/pages/home" for ::1 at 2026-01-22 17:50:39 -0500
```

Here is the GET request coming in an being handled by `ActionDispatch`. So far
so good. 

The next three lines were a little odd:
```
   (0.2ms)  CREATE TABLE "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY) /*application='TestApp'*/
   (0.1ms)  CREATE TABLE "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL) /*application='TestApp'*/
   ActiveRecord::SchemaMigration Load (0.1ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC /*application='TestApp'*/
```

I assume this is do to Rails checking for migrations that have not yet been run.
So I tested again by shutting down and restarting the server. 

The second request, I got no messages about schema migrations. So I restarted
and did it again and got the same flow. 

So my thought is this:

Rails must be checking for those two tables to do the migration middleware. The 
first time it didn't find the tables so it created them. When I restart the 
server, those tables exist so instead of creating them it queries 
`schema_migrations` to check for pending migrations. 

So the pseudocode looks something like this:

```
# on first request
if migration table does not exist:
  create new tables
query migration tables
if migrations exist:
  throw error 
else:
  process request 
```

Moving on in the request:

```sh
Processing by PagesController#home as */*
```

This matches my assumption, we found PagesController and the home action. Not
entirely what `*/*` is but when i add `.json` to the URL I get:

```
Processing by PagesController#home as JSON
```

So this must be the MIME type. So I would revise my assumption to throw in 
that Rails also does a MIME type check when determining what template to load.

Next:

```sh
  Rendering layout layouts/application.html.erb
  Rendering pages/home.html.erb within layouts/application
  Rendered pages/home.html.erb within layouts/application (Duration: 0.1ms | GC: 0.0ms)
  Rendered layout layouts/application.html.erb (Duration: 5.2ms | GC: 1.0ms)
```
So my original flow forgot some stuff. Mainly layouts. Any call to `#render` 
(either explicit or implied) will first load a layout (`application`) and then 
the actual page. If there are partials, they would be listed, presumably in the 
order they appear in the files. Noticeably, we have both `Rendering` and 
`Rendered` which allows for timing analysis (including garbage collection). It
appears that these render outside in with the template rendering first then the 
layout rendering after that, which makes sense. 

```sh
Completed 200 OK in 26ms (Views: 8.5ms | ActiveRecord: 0.0ms (0 queries, 0 cached) | GC: 3.1ms)
```

Finally, we have the HTTP status code (200) and the timing information.

### Claude Comments

**What you nailed:**
- The overall request flow (router → controller → action → view) is correct
- Good instinct to test the schema_migrations behavior by restarting
- Correctly identifying `*/*` as the MIME/Accept type and verifying with `.json`
- Noticing the layout wrapping behavior

**Issues:**

🟡 **Rack/Puma distinction** — You said "ActionDispatch receives the HTTP request." More precisely, **Puma** (the web server) receives the TCP connection and parses the HTTP request into a Rack-compatible env hash. That hash then passes through the **middleware stack** (which you can see with `bin/rails middleware`). ActionDispatch provides many of those middleware layers, but it's not a single entry point — it's a collection of middleware. The router (`ActionDispatch::Routing::RouteSet`) is just one piece near the bottom of that stack.

🟡 **Rendering order** — You said "these render outside in with the template rendering first then the layout rendering after that." Look more carefully at the logs:

```
Rendering layout layouts/application.html.erb        ← layout STARTS
Rendering pages/home.html.erb within layouts/application  ← template renders
Rendered pages/home.html.erb within layouts/application   ← template DONE
Rendered layout layouts/application.html.erb              ← layout DONE
```

The layout starts rendering, hits `<%= yield %>`, which triggers the template render, then the layout finishes. It's outside-in *initiation* but inside-out *completion*. The timing confirms this — the layout duration (5.2ms) includes the template duration (0.1ms).

🟡 **Migration pseudocode** — Your pseudocode says "throw error" for pending migrations. In development, Rails raises `ActiveRecord::PendingMigrationError` which shows a helpful error page — it doesn't silently error. Also worth noting: the middleware responsible is `ActiveRecord::Migration::CheckPending`. This is a good thing to verify on Day 2 when you study the middleware stack with `bin/rails middleware`.

🟢 **One thing to dig deeper on** — You correctly noted the format detection (`*/*` vs `JSON`), but the mechanism is worth understanding: Rails uses both the `Accept` header AND the URL extension to determine format. The controller can then respond differently via `respond_to` blocks. You'll use this later when building the API layer.

**Grade: 82/100**

## Day 2
So...given this is middleware, the "middleware" folder of action_dispatch looked 
the most interesting plcae to start. 😂 Within that folder, `stack.rb` looked 
most promising. The code there was refreshingly simple:

```ruby
def initialize(*args)
  @middlewares = []
  yield(self) if block_given?
end
```

So we store our middleware in a simple array. There also a clear method to 
insert a new middleware:

```ruby
def insert(index, klass, *args, &block)
  index = assert_index(index, :before)
  middlewares.insert(index, build_middleware(klass, args, block))
end
```

The `build_middleware` method here constructs a new `Middleware` instance:

```ruby
def build_middleware(klass, args, block)
  Middleware.new(klass, args, block)
end
```

So now I have some clues, let me see where `MiddlewareStack.new` is called to
see how middleware is loaded.

In `rails/railties/lib/rails/application.rb` we have what I think is what 
goes on:

```ruby
class Application < Engine
    autoload :Bootstrap,              "rails/application/bootstrap"
    autoload :Configuration,          "rails/application/configuration"
    autoload :DefaultMiddlewareStack, "rails/application/default_middleware_stack"
    # ...
    def default_middleware_stack # :nodoc:
      default_stack = DefaultMiddlewareStack.new(self, config, paths)
      default_stack.build_stack
    end
```

The `rails/application/default_middleware_stack` looks promising. And there it
is, where all the middleware is loaded in:

```ruby
def build_stack
        ActionDispatch::MiddlewareStack.new do |middleware|
          unless Array(config.hosts).empty?
            middleware.use ::ActionDispatch::HostAuthorization, config.hosts, **config.host_authorization
          end

          if config.assume_ssl
            middleware.use ::ActionDispatch::AssumeSSL
          end

          if config.force_ssl
            middleware.use ::ActionDispatch::SSL, **config.ssl_options,
              ssl_default_redirect_status: config.action_dispatch.ssl_default_redirect_status
          end
```
Curiously, there's no router in here. Maybe the `#draw` method in `Rails.application` does this.

And then, when I run `bin/rails middleware` I get:

```sh
use ActionDispatch::HostAuthorization
use Rack::Sendfile
use ActionDispatch::Static
use Propshaft::Server
use ActionDispatch::Executor
use ActionDispatch::ServerTiming
use ActiveSupport::Cache::Strategy::LocalCache::Middleware
use Rack::Runtime
use Rack::MethodOverride
use ActionDispatch::RequestId
use ActionDispatch::RemoteIp
use Propshaft::QuietAssets
use Rails::Rack::Logger
use ActionDispatch::ShowExceptions
use WebConsole::Middleware
use ActionDispatch::DebugExceptions
use ActionDispatch::ActionableExceptions
use ActionDispatch::Reloader
use ActionDispatch::Callbacks
use ActiveRecord::Migration::CheckPending
use ActionDispatch::Cookies
use ActionDispatch::Session::CookieStore
use ActionDispatch::Flash
use ActionDispatch::ContentSecurityPolicy::Middleware
use Rack::Head
use Rack::ConditionalGet
use Rack::ETag
use Rack::TempfileReaper
run TestApp::Application.routes
```

Notably, our routes are at the end here.

## Day 3

> Read Rails Guides on Active Record fully. Focus on connection handling and
> query interface.

So the proposed reading `Rails Guides - Active Record Basics` wasn't super help-
ful on these two topics, and did not address true connection handling here. So
I took at a look at the source of ActiveRecord::Base and specifically the 
`#establish_connection` method. This gives a good example of the imperative 
handling of connecting to a database within a Rails app:

```ruby
ActiveRecord::Base.establish_connection(
  adapter:  "mysql2",
  host:     "localhost",
  username: "myuser",
  password: "mypass",
  database: "somedatabase"
)
```

I know that database connection details are stored in `config/database.yml` as 
YAML objects and saw this as well:

```ruby
ActiveRecord::Base.establish_connection(:production)
```

The docs explicitly state:

> In case ActiveRecord::Base.configurations is set (Rails automatically loads 
> the contents of config/database.yml into it), a symbol can also be given as 
> argument, representing a key in the configuration hash.

So I'm curious now how this all wires up in a Rails app.

It seems like Rails maintains a connection pool via the `ActiveRecord::ConnectionAdapters::ConnectionPool`
class. Then, ActiveRecord can lease connections through this pool.

Struggling to find what code is responsible for maintaining this pool. Let's
 start from how to use it. A good example from the docs on `ActiveRecord::Result`:

```ruby
result = ActiveRecord::Base.lease_connection.exec_query('SELECT id, title, body FROM posts')
```
I would think here that `ActiveRecord::Base` is managing the connection pool.
Then `lease_connection` asks the pool for a connection. This is probably 
some type of Connection object which provides a method to execute a query and
return a result.

This is the definition of `lease_connection`:

```ruby
def lease_connection
  connection_pool.lease_connection
end
```

`connection_pool` is a method:

```ruby
def connection_pool
  connection_handler.retrieve_connection_pool(connection_specification_name, role: current_role, shard: current_shard, strict: true)
end
```

This `connection_handler` is an instance of `ConnectionHandler` and it is 
created in ActiveRecord::Core.

```ruby
self.default_connection_handler = ConnectionAdapters::ConnectionHandler.new
```

This is created when `ActiveRecord::Core` is included in `ActiveRecord::Base`
which is what all models extend from.

So let's see how this ties to the query interface. Let's use `#find` as an
example. A quick look shows that `#find` forwards the invocation to 
`#cached_find_by` which is defined by this:

```ruby
def cached_find_by(keys, values)
  with_connection do |connection|
    statement = cached_find_by_statement(connection, keys) { |params|
      wheres = keys.index_with do |key|
        if key.is_a?(Array)
          [key.map { params.bind }]
        else
          params.bind
        end
      end
      where(wheres).limit(1)
    }

    statement.execute(values.flatten, connection).then do |r|
      r.first
    rescue TypeError
      raise ActiveRecord::StatementInvalid
    end
  end
end
```

This reads to me as:

1. Call `with_connection` which yields a connection from the connection pool. This is where the connection management is occuring 
2. Build the statements including the WHERE clauses 
3. Execute the statement using the leased connection and return the first value

## Day 4

> Study Arel and how AR builds SQL. Run `to_sql` on complex queries. Practice joins vs includes vs eager_load vs preload. Rails source - activerecord/lib/arel


The core of ActiveRecord is with its class methods for issuing SQL statements: `find`, `create`, `update`, `destroy`, etc. So what is “Arel” and how does it fit into this picture. 

Arel used to be its [own gem](https://github.com/rails/arel) and has since been moved into ActiveRecord. Looking back before it was merged into ActiveRecord, Arel’s README states:

> Arel is a Relational Algebra for Ruby. It 1) simplifies the generation complex of SQL queries and it 2) adapts to various RDBMS systems. It is intended to be a framework framework; that is, you can build your own ORM with it, focusing on innovative object and collection modeling as opposed to database compatibility and query generation.

A “relational algebra”? Come on, I want to build apps, not do math! But in all seriousness, let’s dig in. 

First, why Arel? Why not just do it all in ActiveRecord? Well, [this article](https://thoughtbot.com/blog/using-arel-to-compose-sql-queries) does a good job of explaining and. Its premise is that a hardcoded  `#where` method is great for constructing basic SQL statements.

```ruby 
where(foo: nil) # => WHERE foo IS NULL
where(foo: ['bar', 'baz']) # => WHERE foo IN ('bar', 'baz')
where(foo: ['bar', 'baz', nil]) # => (WHERE foo IN ('bar', 'baz') OR foo IS NULL)
```

However, these methods breakdown for more complicated SQL expressions, even things as common as `OR` conditions or algebraic formulae. Arel represents more complicated expressions like this in an abstract syntax tree which is—essentially—a tree of components of a given expression. Arel converts a given SQL intent into a series of “nodes” and arranges these nodes into a tree structure to represent the intent of the entire SQL expression. It then applies a visitor pattern to convert this tree into different output formats (MySQL SQL, Postgresql SQL, and even GraphViz)

The key here is that instead of representing SQL as a very long string, Rails uses Arel to provide a syntax for expression SQL queries in an object oriented way. This is a *lot* of theory, let’s see an example.

In a Rails app, we have a Post model:

```sh
Post(id: integer, title: string, body: text, created_at: datetime, updated_at: datetime)
```

To start using Arel without the Rails abstraction, we need to create an `Arel::Table` object that maps to the `posts` table in our SQLite database:

```ruby
table = Arel::Table.new(:posts)
select_manager = table.project(Arel.star)
```

If you execute `table.methods` you’ll find some “SQL-y” method names like `where`. The select “manager” here is an object that processes nodes and can be used to construct the AST and generate SQL therefrom. 

Now the fun part. Let’s execute this:

```ruby
select_manager.to_sql # => "SELECT * FROM \"posts\""
```

Here, the select_manager processed the AST and generate SQL, albeit a lackluster return. But we can use the select manager to add more “nodes” to the tree in an object-oriented fashion:

```ruby
select_manager.where(table[:id].eq(1)).to_sql
```

This will return the SQL:

```sql
"SELECT * FROM \"posts\" WHERE \"posts\".\"id\" = 1 AND \"posts\".\"id\" = 1"
```

As you can see, we start to build more complex queries using a combination of Ruby methods. The AST is a clean way to construct this type of query without unsafe and difficult string manipulation.

Arel is a pretty undocumented library. But, it is critical to ActiveRecord as ActiveRecord uses it under the hood to handle SQL generation. 

You have to kind of turn back time to see the difference. This is the `#find` method in Rails 2 along with some of the other method invocations.

```ruby
# Rails 2.0

options = args.extract_options!
        validate_find_options(options)
set_readonly_option!(options)

case args.first
  when :first then find_initial(options)
  when :all   then find_every(options)
  else             find_from_ids(args, options)
end
# ...
def find_every(options)
  records = scoped?(:find, :include) || options[:include] ?
    find_with_associations(options) : 
    find_by_sql(construct_finder_sql(options))

  records.each { |record| record.readonly! } if options[:readonly]

  records
end
# ...
def construct_finder_sql(options)
  scope = scope(:find)
  sql  = "SELECT #{(scope && scope[:select]) || options[:select] || (options[:joins] && quoted_table_name + '.*') || '*'} "
  sql << "FROM #{(scope && scope[:from]) || options[:from] || quoted_table_name} "

  add_joins!(sql, options, scope)
  add_conditions!(sql, options[:conditions], scope)

  add_group!(sql, options[:group], scope)
  add_order!(sql, options[:order], scope)
  add_limit!(sql, options, scope)
  add_lock!(sql, options, scope)

  sql
end
```

Notably, the `#construct_finder_sql` shows how complicated string building can be and how error prone it can be. Further, there was *no* `#where` in Rails 2.0 for chaining together complex queries. Thus, Arel opens a wider range of expressiveness in SQL queries while allowing ActiveRecord to retain a simple interface. 

### Experimenting with `#to_sql`
Continuing our previous example, I added a `Comment` class which belongs to a Post.

```
test-app(dev):020> Post.joins(:comments).where(id: 1).to_sql
=> "SELECT \"posts\".* FROM \"posts\" INNER JOIN \"comments\" ON \"comments\".\"post_id\" = \"posts\".\"id\" WHERE \"posts\".\"id\" = 1"
```

```
test-app(dev):021> Post.joins(:comments).where(id: 1).limit(5).offset(1).to_sql
=> "SELECT \"posts\".* FROM \"posts\" INNER JOIN \"comments\" ON \"comments\".\"post_id\" = \"posts\".\"id\" WHERE \"posts\".\"id\" = 1 LIMIT 5 OFFSET 1"
```

### Practice joins vs includes vs eager_load vs preload.
So I added three comments to a post and run this code:

```ruby
posts = Posts.limit(10)
posts.each do |p|
	puts p.comments.count
end
```

As is, this make three database queries:

```
Post Load (0.3ms)  SELECT "posts".* FROM "posts" LIMIT 10 /*application='TestApp'*/
  Comment Count (1.2ms)  SELECT COUNT(*) FROM "comments" WHERE "comments"."post_id" = 1 /*application='TestApp'*/
3
  Comment Count (0.1ms)  SELECT COUNT(*) FROM "comments" WHERE "comments"."post_id" = 2 /*application='TestApp'*/
  
```

Let’s see how join, includes, ec. Work:

```ruby
Post.limit(10).joins(:comments)
```

```ruby
#   Post Load (0.3ms)  SELECT "posts".* FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id" /* loading for pp */ LIMIT 10 /*application='TestApp'*/

[#<Post:0x00000001294ace58 id: 1, title: "Test", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-24 15:27:12.225206000 +0000">,
 #<Post:0x00000001294acd18 id: 1, title: "Test", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-24 15:27:12.225206000 +0000">,
 #<Post:0x00000001294acbd8 id: 1, title: "Test", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-24 15:27:12.225206000 +0000">,
 #<Post:0x00000001294aca98 id: 2, title: "Test 2", body: "Another test", created_at: "2026-01-25 01:55:04.034980000 +0000", updated_at: "2026-01-25 01:55:04.034980000 +0000">]
 ```
 
 So now we have one SQL statement, but we have a but of a mess in the results since we have an array the size of the number of comments for the matching post. This isn’t *really* what we want but shows `join` syntax.
 
 Let’s move to the others:
 
 ```sh
 test-app(dev):050> posts = Post.includes(:comments).limit(10); posts.each { |p| puts p.comments.count }
  Post Load (0.2ms)  SELECT "posts".* FROM "posts" LIMIT 10 /*application='TestApp'*/
  Comment Load (0.2ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" IN (1, 2) /*application='TestApp'*/
  Comment Count (0.1ms)  SELECT COUNT(*) FROM "comments" WHERE "comments"."post_id" = 1 /*application='TestApp'*/
3
  Comment Count (0.0ms)  SELECT COUNT(*) FROM "comments" WHERE "comments"."post_id" = 2 /*application='TestApp'*/
1
=>
[#<Post:0x00000001294a35d8 id: 1, title: "Test", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-24 15:27:12.225206000 +0000">,
 #<Post:0x00000001294a3498 id: 2, title: "Test 2", body: "Another test", created_at: "2026-01-25 01:55:04.034980000 +0000", updated_at: "2026-01-25 01:55:04.034980000 +0000">]
test-app(dev):051> posts = Post.preload(:comments).limit(10); posts.each { |p| puts p.comments.count }
  Post Load (0.3ms)  SELECT "posts".* FROM "posts" LIMIT 10 /*application='TestApp'*/
  Comment Load (0.2ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" IN (1, 2) /*application='TestApp'*/
  Comment Count (0.1ms)  SELECT COUNT(*) FROM "comments" WHERE "comments"."post_id" = 1 /*application='TestApp'*/
3
  Comment Count (0.1ms)  SELECT COUNT(*) FROM "comments" WHERE "comments"."post_id" = 2 /*application='TestApp'*/
1
=>
[#<Post:0x000000012b62e4c8 id: 1, title: "Test", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-24 15:27:12.225206000 +0000">,
 #<Post:0x000000012b62e388 id: 2, title: "Test 2", body: "Another test", created_at: "2026-01-25 01:55:04.034980000 +0000", updated_at: "2026-01-25 01:55:04.034980000 +0000">]
test-app(dev):052> posts = Post.eager_load(:comments).limit(10); posts.each { |p| puts p.comments.count }
  SQL (0.3ms)  SELECT DISTINCT "posts"."id" FROM "posts" LEFT OUTER JOIN "comments" ON "comments"."post_id" = "posts"."id" LIMIT 10 /*application='TestApp'*/
  Post Eager Load (0.2ms)  SELECT "posts"."id" AS t0_r0, "posts"."title" AS t0_r1, "posts"."body" AS t0_r2, "posts"."created_at" AS t0_r3, "posts"."updated_at" AS t0_r4, "comments"."id" AS t1_r0, "comments"."content" AS t1_r1, "comments"."post_id" AS t1_r2, "comments"."created_at" AS t1_r3, "comments"."updated_at" AS t1_r4 FROM "posts" LEFT OUTER JOIN "comments" ON "comments"."post_id" = "posts"."id" WHERE "posts"."id" IN (1, 2) /*application='TestApp'*/
  Comment Count (0.1ms)  SELECT COUNT(*) FROM "comments" WHERE "comments"."post_id" = 1 /*application='TestApp'*/
3
  Comment Count (0.1ms)  SELECT COUNT(*) FROM "comments" WHERE "comments"."post_id" = 2 /*application='TestApp'*/
1
=>
[#<Post:0x000000012b649610 id: 1, title: "Test", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-24 15:27:12.225206000 +0000">,
 #<Post:0x000000012b649110 id: 2, title: "Test 2", body: "Another test", created_at: "2026-01-25 01:55:04.034980000 +0000", updated_at: "2026-01-25 01:55:04.034980000 +0000">]
test-app(dev):053>
```
 
 We can ignore the `SELECT COUNT(*)` for now but can note the following:
 
 1. `include` and `preload` reduce to two queries.
 2. `eager_load` results in a single query that uses a LEFT OUTER JOIN

All techniques help to reduce the total number of hits to the database which improves performance. 

## Day 5
> Study AR callbacks lifecycle. Map out the full callback chain for create/update/destroy.

For any ActiveRecord model, callbacks may be **registered**. These are “ordinary methods, blocks and procs, or defining custom callback objects using classes or modules” that are executed are certain defined points in the object **lifecycle**.  

### Registration Methods 
Call backs can be limited to specific lifecycle events using `:on`  when registering a callback:

```ruby
before_validation :ensure_username_has_value, on: :create
# or 
after_validation :set_location, on: [ :create, :update ]
```


#### Macro-style
One of the most common is **macro-style** callback registration which entails calling a class method and passing a symbol:

```ruby
before_validation :ensure_username_has_value
```

During the object lifecycle, ActiveRecord will call the `#ensure_username_has_value` method before validating an ActiveRecord object. These methods should generally be private on the model instance.

#### Block Style 
For shorter hooks, the callback registration method supports a block style syntax:

```ruby
before_validation do
  self.username = email if username.blank?
end
``` 

This is generally preferable for single-line hook bodies as it can clutter the model definitions. 

#### Proc-style
As an alternative to block style, proc-style can be used:

```ruby
before_validation ->(user) { user.username = user.email if user.username.blank?
```

### Custom Callback Object
For more advanced or involved callbacks, you can also define a custom class that includes a corresponding hook method:

```ruby
class User < ApplicationRecord
  validates :username, :email, presence: true

  before_validation AddUsername
end

class AddUsername
  def self.before_validation(record)
    if record.username.blank?
      record.username = record.email
    end
  end
end
```

Such a technique is useful if the callback logic is particularly complex. It also supports file-level separation of concerns.

### Overall Function
Callbacks are generally implemented as hooks surrounding an event. Most callbacks have corresponding “before” and “after” hooks that surround the underlying event. ==Callbacks are only available on the `#create`, `#update`, and `#destroy` actions.== The `#create` and `#update` hooks are very similar while the `#destroy` hooks are much simplified.

### Create
Below is an example class with all `#create` hooks added.

```ruby
class Post < ApplicationRecord
  has_many :comments
  validates :title, presence: true

  before_validation do
    puts "Hello, I'm in the before_validation callback"
  end

  after_validation do
    puts "Hello, I'm in the after_validation callback"
  end

  before_save do
    puts "Hello, I'm in the before_save callback"
  end

  around_save do
    puts "Hello, I'm in the around_save callback"
  end

  before_create do
    puts "Hello, I'm in the before_create callback"
  end

  around_create do
    puts "Hello, I'm in the around_create callback"
  end

  after_create do
    puts "Hello, I'm in the after_create callback"
  end

  after_save do
    puts "Hello, I'm in the after_save callback"
  end

  after_commit do
    puts "Hello, I'm in the after_commit callback"
  end

  after_rollback do
    puts "Hello, I'm in the after_rollback callback"
  end
end
```

All we are doing here is adding a simple log message in each callback to illustrate the chain. Now let’s call some methods.

First, let’s illustrate when the callbacks are *not* called, using `#new`:

```
test-app(dev):005> Post.new(title: "Test", body: "Test")
=> #<Post:0x0000000126cef1e0 id: nil, title: "Test", body: "Test", created_at: nil, updated_at: nil>
```

The create call backs are not called here because we don’t actually hit the database or do any validations. 

But let’s try to validate:

```ruby
test-app(dev):006> p = Post.new(title: "Test", body: "Test")
=> #<Post:0x000000012884f7a0 id: nil, title: "Test", body: "Test", created_at: nil, updated_at: nil>
test-app(dev):007> p.valid?
Hello, I'm in the before_validation callback
Hello, I'm in the after_validation callback
=> true
test-app(dev):008>
```

Here the `before_validation` and `after_validation` call backs run. Notably, this would happen also on update. 

Now, let’s try to save this object `p`:

```
test-app(dev):008> p.save
Hello, I'm in the before_validation callback
Hello, I'm in the after_validation callback
Hello, I'm in the before_save callback
Hello, I'm in the around_save callback
Hello, I'm in the after_save callback
=> nil
```

As expected we validate again so we execute the validate callbacks. We also now execute the `before_save` and `after_save` callbacks around the save action which writes to the database. But what about that `around_save`? To understand this we’ll tweak the `around_save` method:

```ruby
# -- snip --
around_save :around_save_callback
# -- snip --
def around_save_callback
  puts "Hello, I'm before the around_save callback (#{self.inspect})"
	yield
	puts "Hello, I'm after the around_save callback (#{self.inspect})"
end
```

We switch to the macro-style here because we have to `yield` to show the effects. The `yield` statement here yields control to the actual save call, as we’ll see below:

```
test-app(dev):026> Post.new(title: "Test", body: "Test").save
Hello, I'm in the before_validation callback
Hello, I'm in the after_validation callback
Hello, I'm before the around_save callback (#<Post id: nil, title: "Test", body: "Test", created_at: nil, updated_at: nil>)
Hello, I'm in the before_save callback
Hello, I'm in the before_create callback
Hello, I'm in the around_create callback
Hello, I'm in the after_create callback
Hello, I'm after the around_save callback (#<Post id: nil, title: "Test", body: "Test", created_at: "2026-01-25 13:53:56.021554000 +0000", updated_at: "2026-01-25 13:53:56.021554000 +0000">)
Hello, I'm in the after_save callback
```

I included the `self.inspect` call to show that after the yield, the object has be persisted and receives its timestamp updates. Thus, `around_*` calls are useful when you need to perform logic before *and* after the hook. I would presume this is to maintain some sort of tracking or handle some sort of persistence-level issue that separate before and after hooks can’t handle

Finally, let’s check the `#create` method:

```ruby
test-app(dev):029> Post.create(title: "Test", body: "New")
Hello, I'm in the before_validation callback
Hello, I'm in the after_validation callback
Hello, I'm before the around_save callback (#<Post id: nil, title: "Test", body: "New", created_at: nil, updated_at: nil>)
Hello, I'm in the before_save callback
Hello, I'm before the around_create callback (#<Post id: nil, title: "Test", body: "New", created_at: "2026-01-25 13:57:04.995572000 +0000", updated_at: "2026-01-25 13:57:04.995572000 +0000">)
Hello, I'm in the before_create callback
  TRANSACTION (0.1ms)  BEGIN immediate TRANSACTION /*application='TestApp'*/
  Post Create (2.1ms)  INSERT INTO "posts" ("title", "body", "created_at", "updated_at") VALUES ('Test', 'New', '2026-01-25 13:57:04.995572', '2026-01-25 13:57:04.995572') RETURNING "id" /*application='TestApp'*/
Hello, I'm after the around_create callback (#<Post id: 3, title: "Test", body: "New", created_at: "2026-01-25 13:57:04.995572000 +0000", updated_at: "2026-01-25 13:57:04.995572000 +0000">)
Hello, I'm in the after_create callback
Hello, I'm after the around_save callback (#<Post id: 3, title: "Test", body: "New", created_at: "2026-01-25 13:57:04.995572000 +0000", updated_at: "2026-01-25 13:57:04.995572000 +0000">)
Hello, I'm in the after_save callback
  TRANSACTION (0.3ms)  COMMIT TRANSACTION /*application='TestApp'*/
Hello, I'm in the after_commit callback
=> #<Post:0x00000001287ad2e8 id: 3, title: "Test", body: "New", created_at: "2026-01-25 13:57:04.995572000 +0000", updated_at: "2026-01-25 13:57:04.995572000 +0000">

```

Here we have the whole chain:

1. before_validation (essentially the initial state)
2. after_validation (now will have validation errors)
3. around_save (before `yield`) 
4. before_save
5. around_create (before `yield`) (will have timestamps from #save)
6. before_create (last chance before hitting database)
7. around_create  (after `yield`) (will now have database id for rest of call backs)
8. after_create
9. around_save (before `yield`)
10. after_save
11. after_commit

Of note is the `after_commit` call back. In Rails, all operations that modify the database (create, read, update) are wrapped in a transaction so that they can be rolled back if any errors occur. This `after_commit` hook is called after the transation is committed to the database. Similarly, the `after_rollback` commit (not illustrated above) is executed if the transaction fails and Rails has to rollback the transction. This could, as one example, be useful for logging errors related to the transaction.

It should be noted that the *_validation callbacks will also be called when you call `model.valid?` and other vlidtaion methods. In that instance the create/update callbacks won't be called until you create or update. Also note that you can bypass the validation callbacks by saving without validation (`p.save(validate: false)`)

### Update
Many of the callbacks here are similar to `#create`, so we will just add three new ones to our model:

```ruby
# --snip--
around_update :around_update_callback

before_update do
  puts "Hello, I'm in the before_update callback"
end

after_update do
  puts "Hello, I'm in the after_update callback"
end

def around_update_callback
  puts "Hello, I'm before the around_update callback (#{self.inspect})"
  yield
  puts "Hello, I'm after the around_update callback (#{self.inspect})"
end
# --snip--

```

Now, let's update a record:

```ruby
test-app(dev):041> p = Post.first
  Post Load (0.3ms)  SELECT "posts".* FROM "posts" ORDER BY "posts"."id" ASC LIMIT 1 /*application='TestApp'*/
=> #<Post:0x00000001288ba500 id: 1, title: "Try again!", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:12:54.071710000 +0000">
test-app(dev):042> p.title = "Hello world"
=> "Hello world"
test-app(dev):043> p.save
Hello, I'm in the before_validation callback
Hello, I'm in the after_validation callback
Hello, I'm before the around_save callback (#<Post id: 1, title: "Hello world", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:12:54.071710000 +0000">)
Hello, I'm in the before_save callback
Hello, I'm before the around_update callback (#<Post id: 1, title: "Hello world", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:13:42.233250000 +0000">)
Hello, I'm in the before_update callback
  TRANSACTION (0.1ms)  BEGIN immediate TRANSACTION /*application='TestApp'*/
  Post Update (0.5ms)  UPDATE "posts" SET "title" = 'Hello world', "updated_at" = '2026-01-25 14:13:42.233250' WHERE "posts"."id" = 1 /*application='TestApp'*/
Hello, I'm after the around_update callback (#<Post id: 1, title: "Hello world", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:13:42.233250000 +0000">)
Hello, I'm in the after_update callback
Hello, I'm after the around_save callback (#<Post id: 1, title: "Hello world", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:13:42.233250000 +0000">)
Hello, I'm in the after_save callback
  TRANSACTION (0.1ms)  COMMIT TRANSACTION /*application='TestApp'*/
Hello, I'm in the after_commit callback
```

This should look familiar, however instead of the before/around/after_create callbacks we have new before/around/after_update callbacks. Same flow, but capturing different operations (create vs. update).

### Destroy

Finally, we have destroy. With destroy the callback chain is smaller. We don't have saving, we don't have validation, we only have:

```ruby
#--snip--
around_destroy :around_destroy_callback

before_destroy do
  puts "Hello, I'm in the before_destroy callback"
end

after_destroy do
  puts "Hello, I'm in the after_destroy callback"
end

# --snip--
def around_destroy_callback
  puts "Hello, I'm before the around_destroy callback (#{self.inspect})"
  yield
  puts "Hello, I'm after the around_destroy callback (#{self.inspect})"
end
```

Now let's run it:

```ruby
test-app(dev):050> p = Post.first
  Post Load (0.1ms)  SELECT "posts".* FROM "posts" ORDER BY "posts"."id" ASC LIMIT 1 /*application='TestApp'*/
=> #<Post:0x000000012b6865b0 id: 1, title: "Hello world", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:13:42.233250000 +0000">
test-app(dev):051> p.destroy
  TRANSACTION (0.1ms)  BEGIN immediate TRANSACTION /*application='TestApp'*/
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = 1 /*application='TestApp'*/
  Comment Destroy (0.1ms)  DELETE FROM "comments" WHERE "comments"."id" = 1 /*application='TestApp'*/
  Comment Destroy (0.0ms)  DELETE FROM "comments" WHERE "comments"."id" = 2 /*application='TestApp'*/
  Comment Destroy (0.0ms)  DELETE FROM "comments" WHERE "comments"."id" = 3 /*application='TestApp'*/
Hello, I'm before the around_destroy callback (#<Post id: 1, title: "Hello world", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:13:42.233250000 +0000">)
Hello, I'm in the before_destroy callback
  Post Destroy (0.0ms)  DELETE FROM "posts" WHERE "posts"."id" = 1 /*application='TestApp'*/
Hello, I'm after the around_destroy callback (#<Post id: 1, title: "Hello world", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:13:42.233250000 +0000">)
Hello, I'm in the after_destroy callback
  TRANSACTION (0.2ms)  COMMIT TRANSACTION /*application='TestApp'*/
Hello, I'm in the after_commit callback
=> #<Post:0x000000012b6865b0 id: 1, title: "Hello world", body: "Testing Arel", created_at: "2026-01-24 15:27:12.225206000 +0000", updated_at: "2026-01-25 14:13:42.233250000 +0000">
test-app(dev):052>
```

Noticeably here, the ordering is a little different than create/update:

1. around_destroy (before yield, object exists)
2. before_destroy (object exists)
3. around_destroy (after yield, object no longer exists)
4. after_destroy
5. after_commit

So the before/after and around are inverted here.

### Other hooks

There are some other hooks to be aware of:

#### after_initialize, after_find, after_touch
* after_initialize: This is called after you call Model.new 
* after_find: This is called after finder methods like find, first, last, etc. 
* after_touch: called when executing `instance.touch`
Notably, when you call a finder method you will find and initialize an object so they are executed like this:

1. after_find
2. after_initialize

