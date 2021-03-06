require 'simplecov'
SimpleCov.start

if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!
end

require 'rjgit'
include RJGit

TEST_REPO_NAME = "dot_git"
TEST_REPO_PATH = File.join(File.dirname(__FILE__), 'fixtures', TEST_REPO_NAME)
TEST_BARE_REPO_NAME = "dot_bare_git"
TEST_BARE_REPO_PATH = File.join(File.dirname(__FILE__), 'fixtures', TEST_BARE_REPO_NAME)
FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

def valid_repo_attributes
  {
    :path => "/tmp/repo_test"
  }
end

def fixture(name)
  File.read(File.join(File.dirname(__FILE__), 'fixtures', name))
end

def create_temp_repo(clone_path)
  filename = 'git_test' + Time.now.to_i.to_s + rand(300).to_s.rjust(3, '0')
  tmp_path = File.join("/tmp/", filename)
  FileUtils.mkdir_p(tmp_path)
  FileUtils.cp_r(clone_path, tmp_path)
  File.join(tmp_path, File.basename(clone_path))
end

def remove_temp_repo(path)
  if File.exists?(path)
    FileUtils.rm_rf(path)
  else
    puts "\nWARNING: remove_temp_repo could not delete path (directory #{path} does not exist). Called by #{caller[0]}.\n"
  end
end

def get_new_tmprepo_path(bare = false)
  dirname = bare ? 'git_bare_test' : 'git_non_bare_test'
  filename = dirname + Time.now.to_i.to_s + rand(300).to_s.rjust(3, '0')
  result = File.join('/','tmp', filename)
end

# Require any custom RSpec matchers
Dir[File.dirname(__FILE__) + "/support/matchers/*.rb"].each {|f| require f}
