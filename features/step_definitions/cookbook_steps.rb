When /^I check the cookbook$/ do
  run_lint
end

Then /^the (?:[a-z ]+) warning ([0-9]+) should be displayed(?: against the (metadata) file)?$/ do |code, file|
  expect_warning("FC#{code}", file.nil? ? {} : {:file => 'cookbooks/example/metadata.rb'})
end

Then /^the (?:[a-z ]+) warning ([0-9]+) should not be displayed$/ do |code|
  expect_no_warning("FC#{code}")
end

Given /^a cookbook with a single recipe that creates a directory resource with an interpolated name$/ do
  write_recipe %q{
    directory "#{node[:base_dir]}" do
      owner "root"
      group "root"
      mode "0755"
      action :create
    end
  }.strip
end

Given /^a cookbook with a single recipe that creates a directory resource with an interpolated name from a string$/ do
  write_recipe %q{
    directory "#{node['base_dir']}" do
      owner "root"
      group "root"
      mode "0755"
      action :create
    end
  }.strip
end

Given /^a cookbook with a single recipe that creates a directory resource with a string literal$/ do
  write_recipe %q{
    directory "/var/lib/foo" do
      owner "root"
      group "root"
      mode "0755"
      action :create
    end
  }.strip
end

Given /^a cookbook with a single recipe that creates a directory resource with a compound expression$/ do
  write_recipe %q{
    directory "#{node[:base_dir]}#{node[:sub_dir]}" do
      owner "root"
      group "root"
      mode "0755"
      action :create
    end
  }.strip
end

Given /^a cookbook with a single recipe that creates a directory resource with an interpolated variable and a literal$/ do
  write_recipe %q{
    directory "#{node[:base_dir]}/sub_dir" do
      owner "root"
      group "root"
      mode "0755"
      action :create
    end
  }.strip
end

Given /^a cookbook with a single recipe that creates a directory resource with a literal and interpolated variable$/ do
  write_recipe %q{
    directory "base_dir/#{node[:sub_dir]}" do
      owner "root"
      group "root"
      mode "0755"
      action :create
    end
  }.strip
end

Given /^a cookbook with a single recipe that searches without checking if this is server$/ do
  write_recipe %q{nodes = search(:node, "hostname:[* TO *] AND chef_environment:#{node.chef_environment}")}
end

Given /^a cookbook with a single recipe that searches but checks first to see if this is server$/ do
  write_recipe %q{
    if Chef::Config[:solo]
      Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
    else
      nodes = search(:node, "hostname:[* TO *] AND chef_environment:#{node.chef_environment}")
    end
  }.strip
end

Then /^the check for server warning 003 should not be displayed given we have checked$/ do
  expect_warning("FC004", :line => 4, :expect_warning => false)
end

Given /^a cookbook recipe that uses execute to (sleep and then )?start a service via (.*)$/ do |sleep, method|
  cmd = case
          when method.include?('init.d')
            '/etc/init.d/foo start'
          when method.include?('full path')
            '/sbin/service foo start'
          else
            'service foo start'
        end
  write_recipe %Q{
    execute "start-foo-service" do
      command "#{sleep.nil? ? '' : 'sleep 5; '}#{cmd}"
      action :run
    end
  }.strip
end

Given /^a cookbook recipe that uses execute with a name attribute to start a service$/ do
  write_recipe %Q{
    execute "/etc/init.d/foo start" do
      cwd "/tmp"
    end
  }.strip
end

Given /^a cookbook recipe that uses execute to list a directory$/ do
  write_recipe %Q{
    execute "nothing-to-see-here" do
      command "ls"
      action :run
    end
  }.strip
end

Given /^a cookbook recipe that declares multiple resources varying only in the package name$/ do
  write_recipe %Q{
    package "erlang-base" do
      action :install
    end
    package "erlang-corba" do
      action :install
    end
    package "erlang-crypto" do
      action :install
    end
    package "rabbitmq-server" do
      action :install
    end
  }.strip
end

Given /^a cookbook recipe that declares multiple resources with more variation$/ do
  write_recipe %Q{
    package "erlang-base" do
      action :install
    end
    package "erlang-corba" do
      action :install
    end
    package "erlang-crypto" do
      version '13.b.3'
      action :install
    end
    package "rabbitmq-server" do
      action :install
    end
  }.strip
end

Given /^a cookbook recipe that declares multiple package resources mixed with other resources$/ do
  write_recipe %Q{
    package "erlang-base" do
      action :install
    end
    package "erlang-corba" do
      action :install
    end
    service "apache" do
      supports :restart => true, :reload => true
      action :enable
    end
    package "erlang-crypto" do
      action :install
    end
    template "/tmp/somefile" do
      mode "0644"
      source "somefile.erb"
      not_if "test -f /etc/passwd"
    end
    package "rabbitmq-server" do
      action :install
    end
  }.strip
end

Given /^a ([a-z_])+ resource declared with the mode (.*)$/ do |resource,mode|
  source_att = resource == 'template' ? 'source "foo.erb"' : ''
  write_recipe %Q{
    #{resource} "/tmp/something" do
      #{source_att}
      owner "root"
      group "root"
      mode #{mode}
      action :create
    end
  }.strip
end

Given /^a file resource declared without a mode$/ do
  write_recipe %q{
    file "/tmp/something" do
      action :delete
    end
  }.strip
end

Then /^the file mode warning 006 should be (valid|invalid)$/ do |valid|
  if valid == 'valid'
    expect_no_warning('FC006')
  else
    expect_warning('FC006')
  end
end

Given /^a cookbook recipe that includes an undeclared recipe dependency( unscoped)?$/ do |unscoped|
  write_recipe %Q{
    include_recipe 'foo#{unscoped.nil? ? '::default' : ''}'
  }.strip
  write_metadata %q{
    version "1.9.0"
    depends "dogs", "> 1.0"
  }.strip
end

Given /^a cookbook recipe that includes a recipe name from an expression$/ do
  # deliberately not evaluated
  write_recipe %q{
    include_recipe "foo::#{node['foo']['fighter']}"
  }.strip
  write_metadata %q{
    depends "foo"
  }.strip
end

Given /^a cookbook recipe that includes a declared recipe dependency( unscoped)?$/ do |unscoped|
  write_recipe %Q{
    include_recipe 'foo#{unscoped.nil? ? '::default' : ''}'
  }.strip
  write_metadata %q{
    version "1.9.0"
    depends "foo"
  }.strip
end

Given /^a cookbook recipe that includes several declared recipe dependencies - (brace|block)$/ do |brace_or_block|
  write_recipe %q{
    include_recipe "foo::default"
    include_recipe "bar::default"
    include_recipe "baz::default"
  }.strip
  if brace_or_block == 'brace'
    write_metadata %q{
      %w{foo bar baz}.each{|cookbook| depends cookbook}
    }.strip
  else
    write_metadata %q{
      %w{foo bar baz}.each do |cb|
        depends cb
      end
    }.strip
  end
end

Given /^a cookbook recipe that includes both declared and undeclared recipe dependencies$/ do
  write_recipe %q{
    include_recipe "foo::default"
    include_recipe "bar::default"
    file "/tmp/something" do
      action :delete
    end
    include_recipe "baz::default"
  }.strip
  write_metadata %q{
    ['foo', 'bar'].each{|cbk| depends cbk}
  }.strip
end

Then /^the undeclared dependency warning 007 should be displayed only for the undeclared dependencies$/ do
  expect_warning("FC007", :file => 'cookbooks/example/metadata.rb', :line => 1, :expect_warning => false)
  expect_warning("FC007", :file => 'cookbooks/example/metadata.rb', :line => 2, :expect_warning => false)
  expect_warning("FC007", :file => 'cookbooks/example/metadata.rb', :line => 6, :expect_warning => true)
end

Given /^a cookbook recipe that includes a local recipe$/ do
  write_recipe %q{
    include_recipe 'example::server'
  }.strip
  write_metadata %q{
    name 'example'
  }.strip
end

Given /^a cookbook that does not have defined metadata$/ do
  write_recipe %q{
    include_recipe "foo::default"
  }.strip
end

Then /^no error should have occurred$/ do
  assert_exit_status(0)
end

Given /^a cookbook that has the default boilerplate metadata generated by knife$/ do
  write_recipe %q{
    #
    # Cookbook Name:: example
    # Recipe:: default
    #
    # Copyright 2011, YOUR_COMPANY_NAME
    #
    # All rights reserved - Do Not Redistribute
    #
  }.strip
  write_metadata %q{
    maintainer       "YOUR_COMPANY_NAME"
    maintainer_email "YOUR_EMAIL"
    license          "All rights reserved"
    description      "Installs/Configures example"
    long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
    version          "0.0.1"
  }.strip
end

Given /^a cookbook that has maintainer metadata set to (.*) and ([^ ]+)$/ do |maintainer,email|
  write_recipe %q{
    #
    # Cookbook Name:: example
    # Recipe:: default
    #
    # Copyright 2011, YOUR_COMPANY_NAME
    #
    # All rights reserved - Do Not Redistribute
    #
  }.strip

  fields = {}
  fields['maintainer'] = maintainer unless maintainer == 'unspecified'
  fields['maintainer_email'] = email unless email == 'unspecified'
  write_metadata %Q{
    #{fields.map{|field,value| %Q{#{field}\t"#{value}"}}.join("\n")}
    license          "All rights reserved"
    description      "Installs/Configures example"
    long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
    version          "0.0.1"
  }.strip
end

Then /^the boilerplate metadata warning 008 should warn on lines (.*)$/ do |lines_to_warn|
  if lines_to_warn.strip == ''
    expect_no_warning('FC008')
  else
    lines_to_warn.split(',').each{|line| expect_warning('FC008', :line => line, :file => 'cookbooks/example/metadata.rb')}
  end
end