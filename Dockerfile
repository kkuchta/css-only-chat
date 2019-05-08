FROM ruby:2.6.3
MAINTAINER Akky AKIMOTO <akimoto@gmail.com>

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN gem update --system && \
    gem install bundler && \
    bundle update --bundler && \
    bundle install
COPY . .
COPY for-docker.env .env

CMD ["puma"]
