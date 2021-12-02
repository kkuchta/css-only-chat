# The true way

You'll need ruby and redis installed to run this.  If you're on a mac, one way to go getting redis is to install [homebrew](https://brew.sh/), then run `brew install redis`.  Then, for ruby, install [rvm](https://rvm.io/).

Once ruby + redis are installed you can just run `redis-server` in a terminal to start redis.

To boot the ruby web server that serves our html + css:

```
bundle install
bundle exec puma
```

Now you should be able to just visit localhost:9292 in your browser to see the chat.  Open it in a few windows to chat between them!

The web server tries, by default, to talk to redis using its default settings.  If you need to specify different redis config details, create a .env file containining `REDIS_URL=redis://somehost:someport`.  Alternately, provide `REDIS_URL` as an environment variable when running puma, like `REDIS_URL=redis://somehost:someport bundle exec puma`.

# The docker way

If you came here to run this chat, please, re-evaluate your life choices. Ok, done?

This server has been dockerized for the sake of Gambiconf 2021 https://gambiconf.dev/. As a good dockerization, just run `docker-compose up` and you will be served fine.

## Troubleshooting

For some unknown reason, my `dockerd` inside my Hyper-V couldn't solve https://rubygems.org/, so to workaround it I touch another DNS to the daemon:

```bash
$ cat > /etc/docker/daemon.json <<EOL
{
        "dns": [ "8.8.8.8", "8.8.4.4" ]
} 
EOL
$ service docker restart
```

If you face something similiar (or other issues), please re-evaluate your life choices and ALSO drop a PR or an issue.
