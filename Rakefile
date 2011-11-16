require 'rake'

desc "Run specs"
task "spec" => ["bundler:install:test", "test:spec"]

desc "Run functional tests"
task "spec:unit" => ["bundler:install:test", "test:spec:unit"]

desc "Run functional tests"
task "spec:functional" => ["bundler:install:test", "test:spec:functional"]

desc "Run specs using RCov"
task "spec:cov" => ["bundler:install:test", "test:spec:rcov"]

namespace "bundler" do

  desc "Install gems"
  task "install" do
    sh("bundle install")
  end

  environments = %w(test development production)

  environments.each do |env|
    desc "Install gems for #{env}"
    task "install:#{env}" do
      sh("bundle install --local --without #{(environments - [env]).join(' ')}")
    end
  end

end

namespace "test" do

  ["spec", "spec:unit", "spec:functional", "spec:rcov"].each do |task_name|
    task task_name do
      sh("cd spec && rake #{task_name}")
    end
  end

end