vmpuppettest
==================================

Please note this is beta and I will be rolling a gem eventually.
Currently this only works if the top level directory is the same asi the module 
name.

# TODO
Read the modulefile if present to work out the module name.
Wrap into rspec so you can actually run checks on the state of the virtual machine.

# Idea

Run the tests directory in a puppet module actually on a virtual machine. We use 
sahara so we can roll back the state of the machine between tests. I have created
a Vagrant/prerun directory to drop shell scripts in.These are run before sahara is
turned on. This is for cachine packages etc so you dont need to download them each
test.

## Step 1: Setup
First install virtual box

## Step 2: Gems
Install the following gems

* Vagrant
* Sahara
* Rake

## Step 3: Add the rake task

```ruby
require 'pathto/vmpuppettest/lib/vmpuppettest/rake_tasks'
```
to your  Rakefile
## Setp 4: Run setup 
Run rake vmsetup to create all the files we need

## Step 5: Runs the test
Run rake vmtest to run all the tests in tests/
