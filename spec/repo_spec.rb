require 'spec_helper'

describe LocalRefWriter do

  before(:each) do
    @temp_repo_path = create_temp_repo(TEST_REPO_PATH)
    @repo = Repo.new(@temp_repo_path)
    @writer = LocalRefWriter.new(@repo.jrepo.get_all_refs, @repo.path)
  end
  
  it "has a path variable set at initialization" do
    @writer.path.should eql @repo.path
  end
  
  it "writes to the specified file path under the repository's path" do
    filename = File.join('info','nonexistent')
    newfile = File.join(@repo.path, filename)
    File.exists?(newfile).should eql false
    @writer.writeFile(filename, "Test".to_java_bytes)
    File.exists?(newfile).should eql true
  end
  
  it "inherits the write_info_refs method from its JGit superclass" do
    @writer.method(:write_info_refs).owner.should eql Java::OrgEclipseJgitLib::RefWriter
  end
  
  it "throws a Java IOException when the destination file is not writable" do
    expect{ @writer.writeFile("","Test".to_java_bytes) }.to raise_error(IOException)
  end
  
  after(:each) do
    remove_temp_repo(File.dirname(@temp_repo_path))
    @repo = nil
    @writer = nil
    @temp_repo_path = nil
  end

end

describe Repo do

  context "with read-only access" do
    
    before(:each) do
      @create_new = true
      @repo = Repo.new(TEST_REPO_PATH) # Test with both a bare and a non-bare repository
      @bare_repo = Repo.new(TEST_BARE_REPO_PATH, :bare => true, :create => false)
    end

    it "should tell if the repository is valid" do
      tmp_path = get_new_tmprepo_path
      
      tmp_path.should_not exist
      new_repo = Repo.new(tmp_path, :bare => false, :create => false)
      new_repo.valid?.should eql false
      new_repo.create!
      new_repo.valid?.should eql true
      FileUtils.rm_rf(File.join(tmp_path, '.git'))
      new_repo.valid?.should eql false
      remove_temp_repo(tmp_path)
      
      tmp_path.should_not exist
      bare_new_repo = Repo.new(tmp_path, :bare => true, :create => false)
      bare_new_repo.valid?.should eql false
      bare_new_repo.create!
      bare_new_repo.valid?.should eql true
      FileUtils.rm_rf(File.join(tmp_path, 'objects'))
      bare_new_repo.valid?.should eql false
      remove_temp_repo(tmp_path)
    end

    it "should default to a non-bare repository path" do
      @repo.path.should eql File.join(TEST_REPO_PATH, '.git')
    end

    it "should have a bare repository path if specified" do
      File.basename(@bare_repo.path).should_not eql ".git"
    end

    it "should create a new repository on disk immediately" do
      tmp_path = get_new_tmprepo_path
      tmp_path.should_not exist
      new_repo = Repo.new(tmp_path, :bare => false, :create => @create_new)
      result = tmp_path.should exist
      remove_temp_repo(tmp_path)
      result
    end
    
    it "should create an existing repository object on disk" do
      tmp_path = get_new_tmprepo_path
      new_repo = Repo.new(tmp_path, :bare => false, :create => false)
      tmp_path.should_not exist
      new_repo.create!
      tmp_path.should exist
      remove_temp_repo(tmp_path)
    end

    it "should create a new bare repository if specified" do
      tmp_path = get_new_tmprepo_path(true)
      tmp_path.should_not be_a_directory
      new_bare_repo = Repo.new(tmp_path, :bare => true, :create => @create_new)
      result = tmp_path.should be_a_directory
      remove_temp_repo(tmp_path)
      result
    end

    it "should create a new repository on disk" do
      tmp_path = get_new_tmprepo_path(true) # bare repository
      tmp_path.should_not be_a_directory
      new_bare_repo = Repo.create(tmp_path, :bare => true)
      result = tmp_path.should be_a_directory
      remove_temp_repo(tmp_path)
      result
      
      tmp_path = get_new_tmprepo_path # non-bare repository
      tmp_path.should_not exist
      new_repo = Repo.create(tmp_path, :bare => false)
      result = tmp_path.should exist
      remove_temp_repo(tmp_path)
      result
    end
    
    it "should tell us whether it is bare" do
      @repo.should_not be_bare
      @bare_repo.should be_bare
    end

    it "should have a reference to a JGit Repository object" do
      @repo.jrepo.should be_a org.eclipse.jgit.lib.Repository
    end

    it "should have a config" do
      @bare_repo.config.should be_a RJGit::Configuration
    end
    
    it "should list the current branch" do
      @repo.branch.should == "refs/heads/master"
    end

    it "should list its branches" do
      result = @repo.branches
      result.should be_an Array
      result.should include("refs/heads/master")
    end

    it "should list its commits" do
      @repo.commits.should be_an Array
      @repo.commits.length.should > 3
    end
    
    it "should list its tags in name-id pairs" do
      @bare_repo.tags(lightweight=true).should be_a Hash
      @bare_repo.tags(true)["annotated"].should == "b7f932bd02b3e0a4228ee7b55832749028d345de"
    end

    it "should list its tags as Tags" do
      @bare_repo.tags.should be_a Hash
      tag = @bare_repo.tags['annotated']
      tag.should be_a Tag
      tag.id.should == "b7f932bd02b3e0a4228ee7b55832749028d345de"
    end

    it "should return a Blob by name" do
      blob = @bare_repo.blob('lib/grit.rb')
      blob.should_not be_nil
      blob.id.should match /77aa887449c28a922a660b2bb749e4127f7664e5/
      blob.name.should == 'grit.rb'
      blob.jblob.should be_a org.eclipse.jgit.revwalk.RevBlob
    end

    it "should return a Tree by name" do
      tree = @bare_repo.tree('lib')
      tree.should_not be_nil
      tree.id.should match /aa74200714ce8190b38211795f974b4410f5a9d0/
      tree.name.should == 'lib'
      tree.jtree.should be_a org.eclipse.jgit.revwalk.RevTree
    end

    after(:each) do
      @repo = nil
      @bare_repo = nil
    end
  end
  
  context "with write/commit access" do
    before(:each) do
      @temp_repo_path = create_temp_repo(TEST_REPO_PATH)
      @repo = Repo.new(@temp_repo_path)
    end
    
    it "should add files to itself" do
      File.open(File.join(@temp_repo_path, "rspec-addfile.txt"), 'w') {|file| file.write("This is a new file to add.") }
      @repo.add("rspec-addfile.txt")
      @repo.jrepo.read_dir_cache.find_entry("rspec-addfile.txt").should > 0
    end
  
    it "should create a branch" do
      @repo.create_branch('rspec-branch')
      @repo.branches.should include('refs/heads/rspec-branch')
    end
    
    it "should delete a branch" do
      @repo.delete_branch('refs/heads/alternative')
      @repo.branches.should_not include('refs/heads/alternative')
    end
    
    it "should rename a branch" do
      @repo.rename_branch('refs/heads/alternative', 'rspec-branch')
      @repo.branches.should include('refs/heads/rspec-branch')
    end
    
    it "should checkout a branch if clean" do
      result = @repo.git.checkout('refs/heads/alternative')
      result[:success].should be_true
      result[:result].should == 'refs/heads/alternative'
    end
    
    it "should not switch branches if there are conflicts" do
      File.open(File.join(@temp_repo_path, "rspec-conflictingfile.txt"), 'w') {|file| file.write("This is a new file.") }
      @repo.add("rspec-conflictingfile.txt")
      @repo.commit("Creating a conflict - step 1")
      @repo.create_branch('conflict_branch')
      File.open(File.join(@temp_repo_path, "rspec-conflictingfile.txt"), 'a') {|file| file.write("A second line - no conflict yet.") }
      @repo.add("rspec-conflictingfile.txt")
      @repo.commit("Creating a conflict - step 2")
      @repo.checkout('refs/heads/conflict_branch')
      File.open(File.join(@temp_repo_path, "rspec-conflictingfile.txt"), 'a') {|file| file.write("A second line - this should lead to a conflict.") }
      result = @repo.checkout('refs/heads/master')
      result[:success].should be_false
      result[:result].should include 'rspec-conflictingfile.txt'
      @repo.branch.should == 'refs/heads/conflict_branch'
    end
    
    it "should commit files to the repository" do
      RJGit::Porcelain.ls_tree(@repo).should have(5).items
      File.open(File.join(@temp_repo_path, "newfile.txt"), 'w') {|file| file.write("This is a new file to commit.") }
      @repo.add("newfile.txt")
      @repo.commit("Committing a test file to a test repository.")
      RJGit::Porcelain.ls_tree(@repo).should have_at_least(6).items
    end
    
    it "should remove files from the index and the file system" do
      File.open(File.join(@temp_repo_path, "remove_file.txt"), 'w') {|file| file.write("This is a file to remove.") }
      @repo.add("remove_file.txt")
      @repo.commit("Added remove_file.txt")
      "#{@temp_repo_path}/remove_file.txt".should exist
      @repo.remove("remove_file.txt")
      diff = RJGit::Porcelain.diff(@repo, {:cached => true}).first
      @repo.commit("Removed file remove_file.txt.")
      diff[:oldpath].should == 'remove_file.txt'
      diff[:changetype].should == 'DELETE'
      "#{@temp_repo_path}/remove_file.txt".should_not exist
    end
    
    it "should update the server info files" do
      server_info_files = [File.join(@repo.path, 'info','refs'), File.join(@repo.path, 'objects','info','packs')]
      contents = []
      server_info_files.each {|path| f = File.new(path, "r"); contents << f.read; f.close }
      server_info_files.each {|path| f = File.delete(path)}
      @repo.update_server_info
      server_info_files.each_with_index do |path,i|
        f = File.new(path, "r")
        new_contents = ""
	f.each_line do |line|
          new_contents = new_contents + line unless line.include?("refs/heads/.svn/") # JGit (unlike git) also searches directories under refs/heads starting with ".", so it finds some refs in /refs/heads/.svn that git-update-server does not find. See Repo.update_server_info. For now, just filter these lines out.
        end
        new_contents.should eql contents[i]
        f.close
      end
    end
    
    after(:each) do
      remove_temp_repo(File.dirname(@temp_repo_path))
      @repo = nil
    end
  end
  
end
