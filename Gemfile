source "https://rubygems.org"

if ENV['RAILS']  # Use local clone of Rails
  rails_dir = ENV['RAILS']    
  activerecord_dir = ::File.join(rails_dir, 'activerecord')
  
  if !::File.exist?(rails_dir) && !::File.exist?(activerecord_dir)
    raise "ENV['RAILS'] set but does not point at a valid rails clone"
  end

  activemodel_dir =  ::File.join(rails_dir, 'activemodel')
  activesupport_dir =  ::File.join(rails_dir, 'activesupport')
  actionpack_dir =  ::File.join(rails_dir, 'actionpack')
  actionview_dir =  ::File.join(rails_dir, 'actionview')

  gem 'activerecord', require: false, path: activerecord_dir
  gem 'activemodel', require: false, path: activemodel_dir
  gem 'activesupport', require: false, path: activesupport_dir
  gem 'actionpack', require: false, path: actionpack_dir
  gem 'actionview', require: false, path: actionview_dir

elsif ENV['AR_VERSION'] # Use specific version of AR and not .gemspec version
  version = ENV['AR_VERSION']
  
  if !version.eql?('false') # Don't bundle any versions of AR; use LOAD_PATH
    # Specified as raw number. Use normal gem require.
    if version =~ /^([0-9.])+(_)?(rc|RC|beta|BETA|PR|pre)*([0-9.])*$/
      gem 'activerecord', version, require: nil
    else # Asking for git clone specific version
      if version =~ /^[0-9abcdef]+$/ ||                                 # SHA
         version =~ /^v([0-9.])+(_)?(rc|RC|beta|BETA|PR|pre)*([0-9.])*$/# tag
        opts = {ref: version}
      else                                                              # branch
        opts = {branch: version}
      end

      git 'https://github.com/rails/rails.git', **opts do
        gem 'activerecord', require: false
        gem 'activemodel', require: false
        gem 'activesupport', require: false
        gem 'actionpack', require: false
        gem 'actionview', require: false
      end
      
    end
  end
else
  if defined? JRUBY_VERSION
    gemspec name: 'activerecord-jdbc-alt-adapter' # Use versiom from .gemspec
  else # read add_dependency 'activerecord', '~> 7.0' and use the same requirement on MRI
    ar_req = File.read('activerecord-jdbc-adapter.gemspec').match(/add_dependency.*?activerecord.*['"](.*?)['"]/)[1]
    raise "add_dependency 'activerecord', ... line not detected in gemspec" unless ar_req
    gem 'activerecord', ar_req
  end
end

gem 'rake', require: nil

group :test do
  gem 'test-unit', require: nil
  gem 'test-unit-context', require: nil
  gem 'mocha', '~> 1.2', require: false # Rails has '~> 0.14'

  gem 'bcrypt', '~> 3.1.11', require: false
  gem 'jdbc-mssql', '~> 12.2', require: nil
  # gem 'pry-debugger-jruby', platform: :jruby
end

group :rails do
  group :test do
    gem 'minitest', require: nil
    gem 'minitest-excludes', require: nil
    gem 'minitest-rg', require: nil

    gem 'benchmark-ips', require: nil
  end

  # AR expects this for testing xml in postgres (maybe others?)
  gem 'builder', require: nil

  gem 'erubis', require: nil # "~> 2.7.0"

  # Due to rails/activesupport/lib/active_support/message_pack.rb
  gem 'msgpack', '>= 1.7.0', require: false

  # NOTE: due rails/activerecord/test/cases/connection_management_test.rb
  gem 'rack', require: nil

  gem 'zeitwerk'
end

group :development do
  #gem 'ruby-debug', require: nil # if ENV['DEBUG']
  group :doc do
    gem 'yard', require: nil
    gem 'kramdown', require: nil
  end
end

group :test do
  # for testing against different version(s)
  if sqlite_version = ENV['JDBC_SQLITE_VERSION'] 
    gem 'jdbc-sqlite3', sqlite_version, require: nil, platform: :jruby
  end

  gem 'mysql2', '>= 0.4.4', require: nil, platform: :mri
  gem 'pg', '>= 0.18.0', require: nil, platform: :mri
  gem 'sqlite3', '~> 1.4', require: nil, platform: :mri

  # group :mssql do
  #   gem 'tiny_tds', require: nil, platform: :mri
  #   gem 'activerecord-sqlserver-adapter', require: nil, platform: :mri
  # end
end

gem 'pry-nav'
