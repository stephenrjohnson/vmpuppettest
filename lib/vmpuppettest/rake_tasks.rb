require 'rake'
require 'vagrant'
require 'logger'

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG # TODO: get from environment or rspec?
NAME_REGEX = /(^name)\s*'([\w\d\\]+)-([\w\d\\]+)'/

if File::exists?('./Vagrant') 
 @env = Vagrant::Environment::new(:cwd => Dir.getwd+'/Vagrant')
end

def workout_modulename
  if File::exists?('Modulefile')
    File.open("Modulefile", "r") do |infile|
      while (line = infile.gets)
          if  ( name = NAME_REGEX.match(line))
              return name[3]
          end
      end
    end
  end
  return false
end

if workout_modulename
 @modulename = workout_modulename 
else
 @modulename = File.basename(Dir.getwd)
end

def sudo_run(*args)
  @logger.debug("Running command: '#{args[0]}'")
  @env.primary_vm.channel.sudo(args[0]) do |ch, data|
    @logger.debug(data)
  end
end

def puppet_run(manifest)
  modulepath = "--modulepath=/tmp/puppet"
  if File::exists?('spec/fixtures/modules')
    system('rake spec_prep')
    modulepath = "#{modulepath}:/tmp/puppet/#{@modulename}/spec/fixtures/modules"
  end
  sudo_run("puppet apply #{modulepath} #{manifest}")
  sudo_run("puppet apply --detailed-exitcodes #{modulepath} #{manifest}")
end

def prerun
  @logger.debug("Running prerun tasks")
  preruns = Dir.glob("./Vagrant/prerun/*.sh")
  if preruns.count == 0
    @logger.debug("No prerun tasks found, you can add shell scripts in Vagrant/prerun/*.sh")
    @logger.debug("They will be run before sandbox mode is enables, so you can cachce packages etc")
  end
  preruns.each do |prerun|
    sudo_run("bash /tmp/puppet/#{@modulename}/#{preruns}")
  end
end


desc "Display the list of available rake tasks"
task :vmhelp do
    system("rake -T")
end

desc "Create the required directories"
task :vmsetup do
  File::exists?('./tests') || Dir::mkdir('./tests')
  File::exists?('./Vagrant') || Dir::mkdir('./Vagrant')
  File::exists?('./Vagrant/prerun') || Dir::mkdir('./Vagrant/prerun')
  if !File::exists?('./Vagrant/Vagrantfile')
    template = ERB.new <<-EOF
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
    config.vm.box = 'precise64'
    config.vm.box_url = 'http://files.vagrantup.com/precise64.box'
    config.vm.boot_mode = 'gui'
    config.vm.share_folder "puppet", "/tmp/puppet/<%= @modulename %>", "../."
  end
    EOF
    File.open('./Vagrant/Vagrantfile', 'w') {|f| f.write(template.result(binding)) }
  end
end

desc 'Run the puppet manifest in the tests directory'
task :vmtest do
  tests = Dir.glob('./tests/*.pp')

  if tests.count == 0
    @logger.error('No tests found in tests directory')
  elsif !@env.primary_vm.created?
    @logger.debug('Starting Virtual Machine')
    @env.cli('up')
    prerun
  elsif @env.primary_vm.state != :running
    @logger.debug('Starting Virtual Machine')
    @env.cli('up')
  end

  Dir.chdir('./Vagrant')
  @env.cli('sandbox','on')
  Dir.chdir('../')


  tests.each do  |test|
    @logger.debug('Running test #{test}')
    puppet_run("/tmp/puppet/#{@modulename}/#{test}")
    @logger.debug('Rolling back')
    Dir.chdir('./Vagrant')
    @env.cli('sandbox','rollback')
    Dir.chdir('../')
  end
end

desc 'Halt virtual machine'
task :vmhalt do
  if @env.primary_vm.state == :running
    @logger.debug('Shutting Down Virtual Machine')
    @env.cli('halt')
  else
    @logger.error('VirtualMachine not running')
  end
end

desc 'Destroy virtual machine'
task :vmdestroy do
  if @env.primary_vm.created?
    'To destroy please run cd Vagrant && vagrant destry'
  else
    @logger.error('VirtualMachine not created')
  end
end
