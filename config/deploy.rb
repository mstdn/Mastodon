lock '3.8.0'

set :application, 'mastodon'
set :repo_url, 'https://github.com/tootsuite/mastodon.git'
set :branch, 'skylight'
set :rbenv_type, :user
set :rbenv_ruby, File.read('.ruby-version').strip
set :migration_role, :app
set :conditional_migrate, true

append :linked_files, '.env.production', 'public/robots.txt'
append :linked_dirs, 'vendor/bundle', 'public/system'
