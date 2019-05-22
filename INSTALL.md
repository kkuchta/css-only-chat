You'll need ruby and redis installed to run this.  If you're on a mac, one way to go getting redis is to install [homebrew](https://brew.sh/), then run `brew install redis`.
Another way is to install [docker](https://docs.docker.com/docker-for-mac/install/),
then run `docker run --name redis -p 6379:6379 -d redis`.
Then, for ruby, install [rvm](https://rvm.io/).

Once ruby + redis are installed you can just run `redis-server` in a terminal to start redis.

To boot the ruby web server that serves our html + css:

```
gem install bundler
bundle install
bundle exec puma
```

Now you should be able to just visit localhost:9292 in your browser to see the chat.  Open it in a few windows to chat between them!

The web server tries, by default, to talk to redis using its default settings.  If you need to specify different redis config details, create a .env file containining `REDIS_URL=redis://somehost:someport`.  Alternately, provide `REDIS_URL` as an environment variable when running puma, like `REDIS_URL=redis://somehost:someport bundle exec puma`.
