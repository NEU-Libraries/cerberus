

group :frontend do
  guard 'livereload' do
    watch(%r{^app/views/.+\.(erb|haml|slim)$})
    watch(%r{^app/helpers/.+\.rb})
    watch(%r{^public/.+\.(css|js|html)})
    watch(%r{^config/locales/.+\.yml})
    # Rails Assets Pipeline
    watch(%r{(app|vendor)(/assets/\w+/(.+\.(css|js|html))).*}) { |m| "/assets/#{m[3]}" }
    watch(%r{^app/.+\.(erb|haml|js|css|scss|sass|coffee|eco|png|gif|jpg)})
  end
end



