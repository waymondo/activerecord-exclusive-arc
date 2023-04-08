### What does it do?

It allows an ActiveRecord model to exclusively belong to one of any number of different types of ActiveRecord
models.

### Doesn’t Rails already provide this?

It does, but there are decent arguments against the typical Rails way of doing polymorphism. Consider the
fact that the ruby class name is stored in the database as a string. If you want to change the name of the
Ruby class used for such reasons, you must also update the database strings that represent it. The bleeding
of application-layer definitions into the database may become a liability.

Another common argument concerns referential integrity. *Foreign Key Constraints* are a common mechanism to
ensure primary keys of tables can be reliably used as foreign keys on others. This becomes harder to enforce
when a column that represents a Rails class is one of the components required for unique identification.

There are also quality of life considerations, such as not being able to eager-load the `belongs_to ...
polymorphic: true` relationship and the fact that polymorphic indexes require multiple columns.

### So how does this work?

It reduces the boilerplate of managing a *Polymorphic Assication* modeled as a pattern called an *Exclusive
Arc*. This maps nicely to a database constraint, a set of optional `belongs_to` relationships, some
polymorphic methods, and an `ActiveRecord` validation for good measure.

## How to use

Firstly, in your `Gemfile`:

```ruby
gem "activerecord-exclusive-arc"
```

The feature set of this gem is offered via a Rails generator command:

```
bin/rails g exclusive_arc <Model> <arc> <belongs_to1> <belongs_to2> ...
```

This assumes you already have a `<Model>`. The `<arc>` is the name of the polymorphic association you want to
establish that may either be a `<belongs_to1>`, `<belongs_to2>`, etc. Say we ran:

```
bin/rails g exclusive_arc Comment commentable post comment
```

This will inject code into your `Comment` Model:

```ruby
class Comment < ApplicationRecord
  include ExclusiveArc::Model
  exclusive_arc commentable: [:post, :comment]
end
```

At a high-level, this essentially transpiles to the following:

```ruby
class Comment < ApplicationRecord
  belongs_to :post, optional: true
  belongs_to :comment, optional: true
  validate :post_or_comment_present?

  def commentable
    @commentable ||= (post || comment)
  end

  def commentable=(post_or_comment)
    @commentable = post_or_comment
  end
end
```

It's a bit more involved than that, but it demonstrates the essense of the API as an `ActiveRecord` user.

Continuing with our example, the generator command would also produce a migration that looks like this:

```ruby
class CommentCommentableExclusiveArc < ActiveRecord::Migration[7.0]
  def change
    add_reference :comments, :post, foreign_key: true, index: {where: "post_id IS NOT NULL"}
    add_reference :comments, :comment, foreign_key: true, index: {where: "comment_id IS NOT NULL"}
    add_check_constraint(
      :comments,
      "(CASE WHEN post_id IS NULL THEN 0 ELSE 1 END + CASE WHEN comment_id IS NULL THEN 0 ELSE 1 END) = 1",
      name: :commentable
    )
  end
end
```

The database chekc constraint ensures `ActiveRecord` validations can’t be bypassed to break the fabeled
rule - "There Can Only Be One™️". Traditional foreign key constraints can be used and the partial indexes
provide improved lookup performance for each individual polymorphic assoication.

Some options are available to the generator command. You can see them with:

```
$ bin/rails g exclusive_arc --help
Usage:
  rails generate exclusive_arc NAME [arc belongs_to1 belongs_to2 ...] [options]

Options:
  [--skip-namespace], [--no-skip-namespace]                              # Skip namespace (affects only isolated engines)
  [--skip-collision-check], [--no-skip-collision-check]                  # Skip collision check
  [--skip-foreign-key-constraints], [--no-skip-foreign-key-constraints]  # Skip foreign key constraints
  [--skip-foreign-key-indexes], [--no-skip-foreign-key-indexes]          # Skip foreign key partial indexes
  [--skip-check-constraint], [--no-skip-check-constraint]                # Skip check constraint

Runtime options:
  -f, [--force]                    # Overwrite files that already exist
  -p, [--pretend], [--no-pretend]  # Run but do not make any changes
  -q, [--quiet], [--no-quiet]      # Suppress status output
  -s, [--skip], [--no-skip]        # Skip files that already exist

Adds an Exclusive Arc to an ActiveRecord model and generates the migration for it
```

Of course, you can always edit the generated migration by hand instead.

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/waymondo/activerecord-exclusive-arc.

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

