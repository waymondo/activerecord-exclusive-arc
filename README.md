## 💫 `activerecord-exclusive-arc` 💫

A RubyGem that allows an ActiveRecord model to exclusively belong to one of any number of different
types of ActiveRecord models.

### Doesn’t Rails already provide a way to do this?

Yeah but... [here’s a post about why this
exists](https://waymondo.com/posts/are-exclusive-arcs-evil/).

### So how does this work?

It reduces the boilerplate of managing a _Polymorphic Assication_ modeled as a pattern called an
_Exclusive Arc_, where each potential polymorphic reference has its own foreign key. This maps
nicely to a set of optional `belongs_to` relationships, some polymorphic convenience methods, and a
database check constraint with a matching `ActiveRecord` validation.

## How to use

Firstly, add the gem to your `Gemfile` and `bundle install`:

```ruby
gem "activerecord-exclusive-arc"
```

The feature set of this gem is offered via a Rails generator command:

```
bin/rails g exclusive_arc <Model> <arc> <belongs_to1> <belongs_to2> ...
```

This assumes you already have a `<Model>`. The `<arc>` is the name of the polymorphic association
you want to establish that may either be a `<belongs_to1>`, `<belongs_to2>`, etc. Say we ran:

```
bin/rails g exclusive_arc Comment commentable post comment
```

This will inject code into your `Comment` Model:

```ruby
class Comment < ApplicationRecord
  include ExclusiveArc::Model
  has_exclusive_arc :commentable, [:post, :comment]
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

If you need to customize a specific `belongs_to` relationship, you can do so by declaring it before
`has_exclusive_arc`:

```ruby
class Comment < ApplicationRecord
  include ExclusiveArc::Model
  belongs_to :post, -> { where(comments_enabled: true) }, optional: true
  has_exclusive_arc :commentable, [:post, :comment]
end
```

Continuing with our example, the generator command would also produce a migration that looks like
this:

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

The check constraint ensures `ActiveRecord` validations can’t be bypassed to break the fabeled
rule - "There Can Only Be One️". Traditional foreign key constraints can be used and the partial
indexes provide improved lookup performance for each individual polymorphic assoication.

### Exclusive Arc Options

Some options are available to the generator command. You can see them with:

```
$ bin/rails g exclusive_arc --help
Usage:
  rails generate exclusive_arc NAME [arc belongs_to1 belongs_to2 ...] [options]

Options:
  [--optional], [--no-optional]                                          # Exclusive arc is optional
  [--skip-foreign-key-constraints], [--no-skip-foreign-key-constraints]  # Skip foreign key constraints
  [--skip-foreign-key-indexes], [--no-skip-foreign-key-indexes]          # Skip foreign key partial indexes
  [--skip-check-constraint], [--no-skip-check-constraint]                # Skip check constraint

Adds an Exclusive Arc to an ActiveRecord model and generates the migration for it
```

Notably, if you want to make an Exclusive Arc optional, you can use the `--optional` flag. This will
adjust the definition in your `ActiveRecord` model and loosen both the validation and database check
constraint so that there can be 0 or 1 foreign keys set for the polymorphic reference.

### Compatibility

Currently `activerecord-exclusive-arc` is tested against a matrix of:
* Ruby 2.7 and 3.2
* Rails 6.1 and 7.0
* `postgresql` and `sqlite3` database adapters

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/waymondo/activerecord-exclusive-arc.

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
