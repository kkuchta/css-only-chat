FROM ruby:2.7-alpine
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
COPY config.ru /myapp/config.ru
COPY server.rb /myapp/server.rb
COPY style.css /myapp/style.css

RUN apk add make
RUN apk add gcc
RUN apk add musl-dev
RUN bundle install
EXPOSE 9292
CMD bundle exec puma
