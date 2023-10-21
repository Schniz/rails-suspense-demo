# Suspense for Rails

This is a hacky implementation of out-of-order streaming for Rails applications.

## Why?

because it's cool. And lets you defer loading of assets until they are ready without compromising TTFB.

## How?

in your controller, include `ApplicationController::Suspending` and then use `response.stream.write render_to_string` to make sure you don't close the response when rendering:

```ruby
class PostsController < ApplicationController
  include ApplicationController::Suspending

  def show
    response.stream.write render_to_string
  end
end
```

in your ERB view, you can now use `suspense` helper to render a fallback until the data you're looking at is ready.
This is using partials:

1. `app/views/posts/show.html.erb`:

   ```erb
   <p>Comments:</p>
   <%= suspense(
       # the partial to render that will eventually replace the fallback
       partial: "comments",
       locals: { post: @post }
     ) do
   %>
     <%# this is the fallback we render while waiting for the partial to render %>
     Loading comments...
   <% end %>
   ```

2. `app/views/posts/_comments.html.erb`:

   ```erb
   <%# we're sleeping to simulate a slow database query %>
   <% sleep 1 %>
   <ul>
     <% post.comments.each do |comment| %>
       <li><%= comment.body %></li>
     <% end %>
   </ul>
   ```

That's it.

## How does that work?

tl;dr: [Out of order streaming](https://gal.hagever.com/posts/out-of-order-streaming-from-scratch).

1. We kick off the partial rendering in a different thread, storing it in a Thread::Queue so we can retrieve it later. (note: maybe we want to use Fiber in the future?)
1. The `suspense` helper renders a `<x-rails-suspense data-id="unique-id">` tag with the fallback content.
1. On `after_action`, we start draining the thread queue.
   1. On each thread, we get the value and render:
      1. `<template data-for-suspense="unique-id">` tag
      1. a `<script>` tag that replaces the `<x-rails-suspense>` tag with the template content. then we remove the template from the html. This can probably use Turbo Streams to piggyback on the Turbo implementation.
1. We close the response stream

## Source

1. [./app/helpers/application_helper.rb](./app/helpers/application_helper.rb) is where the `suspense` function is implemented
2. [./app/controllers/application_controller.rb](./app/controllers/application_controller.rb) is where the `Suspending` module is implemented
