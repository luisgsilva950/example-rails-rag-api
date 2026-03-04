# CLAUDE.md — Code Guide for this Rails Project

## Philosophy

This project follows three core references:

- **Sandi Metz** — Simple object-oriented code with small classes and single responsibility.
- **Avdi Grimm** — Confident code that doesn't hesitate. Handle inputs early, fail explicitly, never return nil when an object is expected.
- **David Heinemeier Hansson (DHH)** — Convention over Configuration. Use Rails the way it was designed. Resist the temptation to abstract too early.

The golden rule: **simplicity above all**. If the solution feels complicated, it's probably wrong.

---

## PostgreSQL Expertise

You are a **PostgreSQL expert**. Always prefer idiomatic PostgreSQL solutions over generic SQL when they offer better performance, clarity, or functionality. Leverage PostgreSQL-specific features and extensions whenever possible, including but not limited to:

- **PostGIS** — Geospatial data types, spatial indexes, and geographic queries.
- **pgvector** — Vector similarity search for embeddings (cosine, L2, inner product). Ideal for AI/ML and RAG pipelines directly in PostgreSQL.
- **pg_trgm** — Trigram-based text similarity and fuzzy matching.
- **hstore and JSONB** — Flexible key-value and document storage with indexing (GIN/GiST).
- **Full-Text Search** — `tsvector`/`tsquery` for advanced text search instead of `LIKE`/`ILIKE`.
- **CTEs (WITH queries)** — For readable, composable complex queries.
- **Window functions** — `ROW_NUMBER()`, `RANK()`, `LAG()`, `LEAD()`, etc. for analytics.
- **Lateral joins** — For correlated subqueries that need to reference outer query columns.
- **Array and range types** — For structured data that doesn't warrant a separate table.
- **Table partitioning** — For managing large tables with time-series or categorical data.
- **pg_stat_statements** — For query performance analysis and optimization.
- **Custom types, domains, and enums** — For data integrity at the database level.
- **Partial and expression indexes** — For targeted index optimization.
- **UPSERT (INSERT ... ON CONFLICT)** — For atomic insert-or-update operations.
- **LISTEN/NOTIFY** — For lightweight pub/sub within PostgreSQL.
- **Advisory locks** — For application-level locking without table locks.
- **pgcrypto** — Cryptographic functions (`gen_random_uuid()`, `crypt()`, `digest()`) for UUIDs and hashing at the database level.
- **Materialized views** — For precomputed query results with `REFRESH MATERIALIZED VIEW CONCURRENTLY`.
- **Generated columns** — `GENERATED ALWAYS AS` for derived/computed columns stored automatically.
- **Exclusion constraints** — For enforcing non-overlapping ranges (e.g., scheduling, reservations) using GiST.
- **Row-Level Security (RLS)** — For fine-grained, policy-based access control at the database level.
- **Foreign Data Wrappers (FDW)** — For querying external data sources (other databases, APIs, files) as virtual tables.
- **Logical replication** — For selective, table-level replication across PostgreSQL instances.
- **pg_cron** — For scheduling recurring database jobs (vacuum, aggregation, cleanup) inside PostgreSQL.

When writing migrations or queries, always consider whether a PostgreSQL-native feature can replace application-level logic. Database-level constraints and features are faster, safer, and more reliable than application code.

```ruby
# Good: use PostgreSQL-native features
add_column :locations, :coordinates, :st_point, geographic: true, srid: 4326
add_index :locations, :coordinates, using: :gist

add_column :articles, :search_vector, :tsvector
add_index :articles, :search_vector, using: :gin

add_column :settings, :metadata, :jsonb, default: {}
add_index :settings, :metadata, using: :gin

# Bad: reimplementing what PostgreSQL already provides
# Storing lat/lng as separate floats and computing distance in Ruby
# Using LIKE '%term%' instead of full-text search
# Storing JSON as a text column and parsing in application code
```

---

## Engineering Mindset

Think like a **principal engineer**: choose the simplest solution that solves the problem. Resist the urge to over-engineer. Clever code is not good code — clear code is good code.

### Plan before you code

**When a task involves more than a trivial change, plan first.** Break the work into small, concrete steps before writing any code. If the plan looks complex, simplify the approach before proceeding. A good plan reveals unnecessary complexity early.

### Prefer model validations — always

**Data integrity belongs in the model, not in services or controllers.** ActiveRecord validations are the first and strongest line of defense. If a business rule can be expressed as a model validation, it **must** be a model validation. Never duplicate validation logic in services that the model should own.

```ruby
# Good: the model enforces its own integrity
class Developer < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :team, presence: true
end

# Bad: a service manually checking what the model should validate
class CreateDeveloper
  def call(params)
    raise "Name is required" if params[:name].blank?   # this belongs in the model
    raise "Email is invalid" unless params[:email].match?(/@/) # this belongs in the model
    Developer.create!(params)
  end
end
```

### Eliminate conditional complexity

**Avoid `if/else` blocks whenever possible.** Every conditional branch adds cognitive load and a potential bug surface. Prefer:

1. **Guard clauses** — return early, keep the happy path flat.
2. **Polymorphism** — replace conditionals with objects that respond to the same interface.
3. **Hash lookups / constants** — replace `if/elsif` chains with a simple mapping.
4. **ActiveRecord scopes and validations** — let the framework handle conditional data logic.
5. **Default values** — eliminate nil checks by providing sensible defaults.

```ruby
# Good: guard clause, flat and readable
def call(record)
  return unless record.actionable?

  process(record)
end

# Good: hash lookup instead of conditionals
BUCKET_STRATEGIES = {
  "daily"   => DailyBucket,
  "weekly"  => WeeklyBucket,
  "monthly" => MonthlyBucket
}.freeze

def bucket_for(group_by)
  BUCKET_STRATEGIES.fetch(group_by)
end

# Bad: nested if/else that grows over time
def bucket_for(group_by)
  if group_by == "daily"
    DailyBucket
  elsif group_by == "weekly"
    WeeklyBucket
  elsif group_by == "monthly"
    MonthlyBucket
  else
    raise "Unknown group_by"
  end
end
```

### When in doubt, simplify

- If a method needs an `else`, question whether the `if` is necessary at all.
- If a class needs more than one public method, question whether it's doing too much.
- If a feature requires more than 3 new files, question the approach.
- If you can't explain the solution in one sentence, it's too complex.

---

## Sandi Metz's Rules

Strictly apply the four rules:

1. **Classes with no more than 100 lines.**
2. **Methods with no more than 5 lines.**
3. **Methods receive no more than 4 parameters** (hash options counts as 1).
4. **Controllers: a single instance variable passed to the view.**

When a rule needs to be broken, require an explicit justification in a code comment.

---

## SOLID Principles

This project follows the five SOLID principles. **SRP** and **DIP** are the most critical and must be applied rigorously.

### Single Responsibility Principle (SRP) ⭐

Each class does **one thing only**. If you need to use "and" to describe what the class does, it does too much.

- Models: validations, associations, and queries (scopes). Nothing more.
- Controllers: receive request, delegate to a service/model, respond. Nothing more.
- Services: one business operation. One public method `call`. Nothing more.
- Views: presentation. Zero logic. Delegate to helpers or presenters.
- Query Objects: encapsulate one complex query. Nothing more.
- Presenters: format data for the view. Nothing more.

A class that changes for more than one reason violates SRP. When in doubt, split it.

```ruby
# Good: each class has a single reason to change
class FilterBugs        # responsibility: apply filters to a scope
class BuildTimeSeries   # responsibility: group data into time buckets
class SerializeBug      # responsibility: format a bug for JSON output

# Bad: one class doing filtering, grouping, formatting, and rendering
class BugsReportController
  def index
    # 50 lines of filtering, grouping, formatting...
  end
end
```

### Open/Closed Principle (OCP)

Classes should be **open for extension, closed for modification**. Prefer adding new classes or strategies instead of modifying existing ones with conditionals.

```ruby
# Good: extend behavior via new classes
class WeeklyBucket
  def call(time) = time.beginning_of_week(:monday).strftime("%Y-%m-%d")
end

class MonthlyBucket
  def call(time) = time.strftime("%Y-%m")
end

# Bad: growing switch/case for each new bucket type
def time_bucket(time)
  case @group_by
  when "daily" then ...
  when "weekly" then ...
  when "monthly" then ...
  # adding new types requires modifying this method
  end
end
```

### Liskov Substitution Principle (LSP)

Subtypes must be substitutable for their base types without breaking behavior. In Ruby, this means respecting the **duck typing contract**: if two objects respond to the same interface, they must behave consistently.

```ruby
# Good: both respond to `call` with the same contract
class JiraClient
  def call(jql:) = # returns array of issues
end

class FakeJiraClient
  def call(jql:) = # returns array of test issues
end
```

### Interface Segregation Principle (ISP)

Don't force clients to depend on methods they don't use. Keep interfaces small and focused. In Ruby, prefer small, specific duck types over large multi-method interfaces.

```ruby
# Good: service depends only on the `call` method of the client
class SyncJiraBugs
  def initialize(client:)  # client only needs to respond to `call`
    @client = client
  end
end

# Bad: service receives a God Object and uses only one method
class SyncJiraBugs
  def initialize(app:)  # depends on entire application context
    @client = app.jira_client
  end
end
```

### Dependency Inversion Principle (DIP) ⭐

High-level modules must **not** depend on low-level modules. Both should depend on abstractions. In Ruby, this translates to: **always inject dependencies via constructor**, never instantiate collaborators internally.

This is the most impactful principle for testability and decoupling.

```ruby
# Good: depends on abstraction (any object responding to the expected interface)
class MetricsExtractor
  def initialize(client:, configuration:)
    @client = client
    @configuration = configuration
  end

  def call
    data = @client.fetch_metrics
    @configuration.apply(data)
  end
end

# Usage: dependencies are wired at the boundary
MetricsExtractor.new(
  client: GithubClient.new,
  configuration: MetricsConfiguration.new
).call

# Bad: hard-coded dependency — couples to concrete implementation
class MetricsExtractor
  def initialize
    @client = GithubClient.new          # violation: creates its own dependency
    @configuration = MetricsConfiguration.new
  end
end
```

**Rules for DIP in this project:**

1. **Services receive all collaborators in the constructor** via keyword arguments with sensible defaults.
2. **Controllers wire dependencies** — they are the composition root where concrete classes are instantiated and injected.
3. **Never call `.new` on collaborator classes inside a service.** If a service needs another service, inject it.
4. **Tests benefit directly** — inject fakes/stubs at construction time instead of monkey-patching.

```ruby
# Good: defaults make production wiring easy, tests can inject fakes
class SyncJiraBugs
  def initialize(client: JiraClient.new, normalizer: CategoriesNormalizer.new)
    @client = client
    @normalizer = normalizer
  end

  def call(jql:)
    issues = @client.call(jql: jql)
    issues.each { |issue| @normalizer.call(issue) }
  end
end

# In tests: inject a fake client
SyncJiraBugs.new(client: FakeJiraClient.new).call(jql: "...")
```

---

## Design Principles

### Composition over Inheritance

**Always prefer composition over inheritance.** Build behavior by composing small, focused objects instead of creating deep inheritance hierarchies.

- Use inheritance only for genuine "is-a" relationships (e.g., `ApplicationController`, `ApplicationRecord`).
- Use modules/concerns only to share interface, never to share state.
- If a concern is used by a single class, inline the logic — the concern is hiding complexity without adding value.
- When you need shared behavior, inject a collaborator instead of inheriting from a base class.

```ruby
# Good: compose small objects
class BuildBugsReport
  def initialize(filter: FilterBugs.new, serializer: SerializeBug.new)
    @filter = filter
    @serializer = serializer
  end

  def call(scope:, params:)
    filtered = @filter.call(scope: scope, params: params)
    filtered.map { |bug| @serializer.call(bug) }
  end
end

# Bad: deep inheritance to share behavior
class BaseReport
  def filter(scope) = # ...
  def serialize(record) = # ...
end

class BugsReport < BaseReport
  def call(scope:, params:)
    serialize(filter(scope))
  end
end
```

**When to use inheritance:** Rails framework classes (`ApplicationController`, `ApplicationRecord`, `ApplicationJob`). These are framework extension points, not domain abstractions.

**When NOT to use inheritance:** Sharing logic between domain classes. Use composition + dependency injection instead.

---

## Rails Conventions (The Rails Way)

### Models

- Keep models thin. Validations, associations, and scopes belong here.
- **Always prefer model validations.** If a constraint can be expressed as a validation, it must live in the model — not in a service, controller, or callback. The model is the single source of truth for data integrity.
- Extract business logic to Services.
- Callbacks (`before_save`, `after_create`) should be simple with no complex side effects. If a callback does anything beyond preparing the record's own data, move it to a Service.
- Scopes should be composable and reusable.

```ruby
class JiraBug < ApplicationRecord
  validates :issue_key, :title, :opened_at, presence: true
  validates :issue_key, uniqueness: true

  scope :recent, -> { where("opened_at >= ?", 30.days.ago) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
end
```

### Controllers

- Controllers are **routers**, not business logic.
- Each action should have at most ~5 lines in the body.
- An action does: fetch/build resource → execute operation → respond.
- Use `before_action` for shared setup (find resource, authenticate).
- Never run complex queries directly in the controller. Delegate to model scopes or query objects.

```ruby
class Metrics::AuthorsController < ApplicationController
  def index
    result = AuthorsRanking.call(page: params[:page], size: params[:size])
    render json: result
  end
end
```

### Services (app/services/)

- One class, one public method: `call`.
- Descriptive name in `VerbSubject` format: `ExtractMetrics`, `NormalizeAuthorName`, `SyncJiraBugs`.
- Receive dependencies in the constructor, operation data in `call`.
- Return a simple result (object, hash, or use the Result pattern if needed).

```ruby
class NormalizeAuthorName
  def initialize(mappings: AuthorNameMappings.new)
    @mappings = mappings
  end

  def call(name)
    return nil if name.nil?

    canonical = @mappings.find(name)
    (canonical || name).strip.downcase
  end
end
```

### Query Objects (app/queries/)

When a query is too complex for a scope, extract it into a Query Object.

```ruby
class AuthorsRankingQuery
  def initialize(relation: Commit.all)
    @relation = relation
  end

  def call(page:, size:)
    @relation
      .where.not(normalized_author_name: [nil, ""])
      .group(:normalized_author_name)
      .select("normalized_author_name AS author", "COUNT(*) AS total_commits")
      .order("total_commits DESC")
      .limit(size)
      .offset((page - 1) * size)
  end
end
```

### Views and Presenters

- Views are templates. Zero complex conditional logic.
- Use helpers for simple formatting.
- For richer presentation logic, use Presenters (POROs that wrap the model).

---

## Confident Code (Avdi Grimm)

### Handle inputs at the boundary

Convert and validate data as early as possible. Inside the system, trust that data is correct.

```ruby
# Good: convert at the entry point
def call(name)
  name = name.to_s.strip
  return nil if name.empty?

  normalize(name)
end

# Bad: check nil everywhere
def call(name)
  return nil if name.nil?
  return nil if name.strip.empty?
  # ...
end
```

### Never return nil silently

If an operation can fail, be explicit. Use exceptions for exceptional errors, `NullObject` pattern for expected absence, or return a default value.

### Guard clauses instead of nested if/else

```ruby
# Good
def process(record)
  return unless record.valid?
  return if record.processed?

  execute(record)
end

# Bad
def process(record)
  if record.valid?
    unless record.processed?
      execute(record)
    end
  end
end
```

---

## Tests

### Mandatory rule: every change must have tests

**No code change is considered complete without corresponding tests.** This includes:

- New features: test the expected behavior and edge cases.
- Bug fixes: add a test that reproduces the bug before fixing it, ensuring it doesn't regress.
- Refactors: maintain or adapt existing tests to cover the preserved behavior.
- New services, models, controllers, or queries: each must have its corresponding test file.

If a change cannot be tested (e.g., infrastructure configuration), justify explicitly in the PR.

### General principles

- Use **RSpec** as the project's testing standard.
- Test behavior, not implementation.
- A test should answer: "what happens when...?"
- Prefer **integration tests** that exercise the full stack (request specs for controllers, service calls with real dependencies).
- **No mocks by default.** Use real objects and real database interactions. Mocks/stubs are only acceptable at hard external boundaries (third-party APIs, external HTTP calls) where real calls are impractical.
- Use `let` and `let!` for setup. Prefer `FactoryBot` for test data.
- Keep tests independent — no reliance on execution order.

### Test types (in order of preference)

1. **Integration / Request specs** — Test the full request-response cycle. This is the primary way to test controllers.
2. **Model specs** — Test validations, associations, scopes, and any model-level logic.
3. **Service specs** — Test the `call` method with real dependencies. Cover happy path and edge cases.
4. **Query object specs** — Test with a real database and real records.

### Test structure

- Organize tests mirroring the `app/` structure: `spec/services/`, `spec/models/`, `spec/requests/`, `spec/queries/`.
- Name the test file with the `_spec.rb` suffix, matching the source file (e.g., `app/services/normalize_author_name.rb` → `spec/services/normalize_author_name_spec.rb`).
- Cover the happy path and edge cases (nil, empty string, invalid data, etc.).

### Example — Service spec

```ruby
RSpec.describe NormalizeAuthorName do
  subject(:normalizer) { described_class.new }

  it "normalizes name to lowercase" do
    expect(normalizer.call("John Doe")).to eq("john doe")
  end

  it "returns nil for nil input" do
    expect(normalizer.call(nil)).to be_nil
  end
end
```

### Example — Request (integration) spec

```ruby
RSpec.describe "Metrics::Authors", type: :request do
  describe "GET /metrics/authors" do
    it "returns a list of authors ranked by commits" do
      create(:commit, normalized_author_name: "jane doe")
      create(:commit, normalized_author_name: "jane doe")
      create(:commit, normalized_author_name: "john doe")

      get "/metrics/authors", params: { page: 1, size: 10 }

      expect(response).to have_http_status(:ok)
      expect(parsed_body.first["author"]).to eq("jane doe")
    end
  end
end
```

### Running the tests

- Run all tests before opening a PR: `bundle exec rspec`.
- Run a specific file: `bundle exec rspec spec/services/normalize_author_name_spec.rb`.
- Run a specific test by line number: `bundle exec rspec spec/services/normalize_author_name_spec.rb:5`.

---

## Directory Structure

```
app/
  controllers/    # HTTP routing and response. Thin.
  models/         # ActiveRecord. Validations, associations, scopes.
  services/       # Business operations. One class = one operation.
  queries/        # Query objects for complex queries.
  presenters/     # Presentation logic for views.
  helpers/        # Simple formatting for views.
  views/          # Templates. Zero logic.
  jobs/           # Background jobs. Delegate to services.
```

---

## Naming

- Classes: nouns or `VerbSubject` for services (`ExtractMetrics`, `SyncJiraBugs`).
- Methods: descriptive verbs. `calculate_total`, `normalize`, `process`.
- Variables: descriptive. Avoid abbreviations. `author_name` instead of `an`.
- Scopes: descriptive and composable. `recent`, `by_status`, `merged`.
- Avoid `get_`/`set_` prefixes. Ruby doesn't use them.

---

## What NOT to do

- **Don't create premature abstractions.** Wait until you have 3 cases before abstracting (Rule of Three).
- **Don't use concerns to hide complexity.** If the concern is only used by one class, the logic belongs in that class.
- **Don't create God Objects.** If the class has more than 100 lines, split it.
- **Don't put business logic in controllers or callbacks.** Move it to services.
- **Don't validate in services what the model should validate.** Data integrity rules belong in model validations.
- **Don't write `if/else` when a guard clause, polymorphism, or hash lookup will do.** Flat code is better than nested code.
- **Don't skip planning.** If the task is non-trivial, break it into steps first. Coding without a plan leads to over-engineering.
- **Don't use `rescue Exception`.** Use `rescue StandardError` or specific exceptions.
- **Don't silence errors.** Log at minimum. Prefer to fail loudly.
- **Don't use metaprogramming** unless the benefit is very clear and the resulting code is readable.

---

## RuboCop

This project uses **RuboCop** with the `rubocop-rails-omakase` style guide as its base configuration (see `.rubocop.yml`).

**All code must pass `bin/rubocop` with zero offenses.** This is enforced in CI.

### Rules

1. **Never ignore or disable RuboCop rules** without an explicit, justified comment (`# rubocop:disable ...` with a reason).
2. **Follow the project's RuboCop configuration exactly.** Do not override rules inline for convenience.
3. **Prefer double-quoted strings** (`"hello"`) unless single quotes are needed to avoid backslash escaping. This is the project standard.
4. **Run `bin/rubocop` before committing.** Use `bin/rubocop -A` to auto-correct safe offenses when appropriate.
5. **When RuboCop and this guide conflict, RuboCop wins.** The `.rubocop.yml` configuration is the authoritative source for style rules.

---

## Checklist before each PR

- [ ] Does each class have a single responsibility?
- [ ] Classes under 100 lines?
- [ ] Methods under 5 lines?
- [ ] Controller actions with at most one instance variable?
- [ ] Business logic in services, not in controllers/models?
- [ ] Complex queries in scopes or query objects?
- [ ] Tests (RSpec) cover the added/changed behavior?
- [ ] Integration tests for new endpoints?
- [ ] No unnecessary mocks — real objects and real DB used?
- [ ] Names are clear and descriptive?
- [ ] Dependencies are injected, not hard-coded?
- [ ] No `.new` calls on collaborators inside services (DIP)?
- [ ] New behavior added via new classes, not conditionals in existing ones (OCP)?
- [ ] Data integrity rules expressed as model validations, not service-level checks?
- [ ] Minimal `if/else` — guard clauses, polymorphism, or hash lookups used instead?
- [ ] Complex tasks planned and broken into steps before coding?
- [ ] `bin/rubocop` passes with zero offenses?
