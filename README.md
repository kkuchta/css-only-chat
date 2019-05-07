![](https://media.giphy.com/media/dWkxAZTg9NbAhvRqOe/giphy.gif)

# CSS-Only Chat
A truly monstrous async web chat using no JS whatsoever on the frontend.

![](https://media.giphy.com/media/mCClSS6xbi8us/giphy.gif)

# Wait what
This is an asynchronous chat that sends + receives messages in the browser with no reloads and no javascript.

## Ok so how

Background-images loaded via pseudoselectors + a forever-loading index page (remember [Comet](https://en.wikipedia.org/wiki/Comet_(programming))?).

## Say that again?

Ok, so there are two things we need the browser to do: send data and receive data.  Let's start with the first.

### Sending Data
CSS is really limited in what it can do.  However, we _can_ use it to effectively detect button presses:

```
.some-button:active {
  background-image: url('some_image.jpg')
}
```

What's cool is that a browser won't actually load that background image until this selector is used - that is, when this button is pressed.  So now we have a way to trigger a request to a server of our choice on a button press.  That sounds like data sending!

Now, of course, this only works once per button (since a browser won't try to load that image twice), but it's a start.

### Receiving Data
