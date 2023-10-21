module ApplicationHelper
  def suspense(partial:, **cfg, &block)
    storage = controller.suspense
    hex = SecureRandom.uuid
    thread = Thread.new do
      value = storage.render_to_string partial: partial, **cfg
      template = content_tag :template, value, data: { for_suspense: hex }
      script = content_tag :script, <<~JS.html_safe
      (() => {
        let template = document.querySelector(`template[data-for-suspense="#{hex}"]`)
        let div = document.querySelector(`x-rails-suspense[data-id="#{hex}"]`)
        div.outerHTML = template.innerHTML
        template.remove();
      })();
      JS
      template + script
    end
    storage.promises.push thread

    fallback = capture(&block)
    content_tag :"x-rails-suspense", fallback, data: { id: hex }
  end
end
