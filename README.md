[![Lines of Code](http://img.shields.io/badge/lines_of_code-237-brightgreen.svg?style=flat)](http://blog.codinghorror.com/the-best-code-is-no-code-at-all/)

# Polysearch

Simplified polymorphic full text + similarity search based on postgres.

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
          make_tsvector(nickname, weight: "B")
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
    User.create first_name: "Shawn", last_name: "Spencer", nickname: "Maverick"

    # find natural language matches (faster)
    User.full_text_search("shawn")

    # find similarity matches, best for misspelled search terms (slower)
    User.similarity_search("shwn")

    # perform a combined full text search and a similarity search
    User.combined_search("shwn")

    # perform a full text search and fall back to similarity (faster than combined_search)
    User.polysearch("shwn")

    # calculate counts (explicitly pass :id to omit search rankings)
    User.full_text_search("shawn").count(:id)
    User.similarity_search("shwn").count(:id)
    User.combined_search("shwn").count(:id)
    User.polysearch("shwn").count(:id)
    ```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
