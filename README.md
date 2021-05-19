[![Lines of Code](http://img.shields.io/badge/lines_of_code-218-brightgreen.svg?style=flat)](http://blog.codinghorror.com/the-best-code-is-no-code-at-all/)

# Polysearch

Simplified polymorphic full text + similarity search based on postgres

> NOTE: This project is narrower in scope and more opinionated than [pg_search](https://github.com/Casecommons/pg_search).

## Requirements

- Postgresql >= 11
- Rails >= 6.0

## Usage

1. Add the gem to your project

    ```sh
    bundle add polysearch
    ```

1. Run the generator

    ```sh
    bundle exec rails g polysearch:migration
    ```

    You can also specify a datatype that your app uses for primary keys (default is `bigint`).
    For example, if your application uses `uuid` primary keys, you install the migration like this.

    ```sh
    bundle exec rails g polysearch:migration uuid
    ```

1. Migrate the database

    ```sh
    bundle exec rails db:migrate
    ```

1. Update the model(s) you'd like to search

    ```ruby
    class User < ApplicationRecord
      include Polysearch::Searchable

      after_save_commit :update_polysearch

      def to_tsvectors
        [
          make_tsvector(first_name, weight: "A"),
          make_tsvector(last_name, weight: "A"),
          make_tsvector(email, weight: "B")
        ]
      end
    end
    ```

    If you have existing records that need to create/update a polysearch record, you can save them like this.

    ```ruby
    User.find_each(&:update_polysearch)
    ```

1. Start searching

    ```ruby
    User.create first_name: "Nate", last_name: "Hopkins", email: "nhopkins@mailinator.com"

    User.polysearch("nate")
    User.polysearch("ntae") # misspellings also return results
    User.polysearch("nate").where(created_at: 1.day.ago..Current.time) # active record chaining
    User.polysearch("nate").order(created_at: :desc) # chain additional ordering after the polysearch scope
    ```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
