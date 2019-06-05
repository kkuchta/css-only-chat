FROM ruby:latest

COPY . .
RUN apt-get update && apt-get install -y redis-server && gem install bundler -v '2.0.1' && bundle update --bundler
CMD eval 'redis-server &' && bundle install && bundle exec puma



