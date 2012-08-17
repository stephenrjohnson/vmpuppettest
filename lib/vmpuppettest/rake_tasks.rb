require 'rake'
require 'vagrant'
require 'logger'

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG # TODO: get from environment or rspec?
if !File::exists?('./Vagrant') 
  @logger.error('Please run the setup rake teask')
else
  @env = Vagrant::Environment::new(:cwd => Dir.getwd+'/Vagrant')
end
@dirname = File.basename(Dir.getwd)

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
    modulepath = "#{modulepath}:/tmp/puppet/#{@dirname}/spec/fixtures/modules"
  end
  sudo_run("puppet apply #{modulepath} #{manifest}")
  sudo_run("puppet apply --detailed-exitcodes #{mdoulepath} #{manifest}")
end

def prerun
  @logger.debug("Running prerun tasks")
  preruns = Dir.glob("./Vagrant/prerun/*.sh")
  if preruns.count == 0
    @logger.debug("No prerun tasks found, you can add shell scripts in Vagrant/prerun/*.sh")
    @logger.debug("They will be run before sandbox mode is enables, so you can cachce packages etc")
  end
  preruns.each do |prerun|
    sudo_run("bash /tmp/puppet/#{@dirname}/#{preruns}")
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
    config.vm.share_folder "puppet", "/tmp/puppet/<%= @dirname %>", "../."
  end
    EOF
    File.open('./Vagrant/Vagrantfile', 'w') {|f| f.write(template.result(binding)) }
  end
end

desc "Run the puppet manifest in the tests directory"
task :vmtest do
  tests = Dir.glob("./tests/*.pp")
  if tests.count == 0
    @logger.error('No tests found in tests directory')
  elsif !@env.primary_vm.created?
    @logger.debug('Starting Virtual Machine')
    @env.cli("up")
    prerun
    @logger.debug("Starting sandbox")
    @env.cli("sandbox on")
  elsif @env.primary_vm.state != :running
    @logger.debug('Starting Virtual Machine')
    @env.cli("up")
  end

  tests.each do  |test|
    @logger.debug("Running test #{test}")
    puppet_run("/tmp/puppet/#{@dirname}/#{test}")
    @env.cli("sandbox rollback")
  end
end

desc "Halt virtual machine"
task :vmhalt do
  if @env.primary_vm.state == :running
    @logger.debug("Shutting Down Virtual Machine")
    @env.cli("halt")
  else
    @logger.error('VirtualMachine not running')
  end
end

desc "Destroy virtual machine"
task :vmdestroy do
  if @env.primary_vm.created?
    "To destroy please run cd Vagrant && vagrant destry"
  else
    @logger.error('VirtualMachine not created')
  end
end
