#
# Copyright:: Copyright 2016-2017, Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "spec_helper"
require "functional/resource/base"
require "chef/mixin/shell_out"

# run this test only for following platforms.
exclude_test = !(%w{rhel fedora}.include?(ohai[:platform_family]) && !File.exist?("/usr/bin/dnf"))
describe Chef::Resource::YumPackage, :requires_root, :external => exclude_test do
  include Chef::Mixin::ShellOut

  def flush_cache
    Chef::Resource::YumPackage.new("shouldnt-matter", run_context).run_action(:flush_cache)
  end

  def preinstall(*rpms)
    rpms.each do |rpm|
      shell_out!("rpm -ivh #{CHEF_SPEC_ASSETS}/yumrepo/#{rpm}")
    end
    flush_cache
  end

  before(:each) do
    File.open("/etc/yum.repos.d/chef-yum-localtesting.repo", "w+") do |f|
      f.write <<-EOF
[chef-yum-localtesting]
name=Chef DNF spec testing repo
baseurl=file://#{CHEF_SPEC_ASSETS}/yumrepo
enable=1
gpgcheck=0
      EOF
    end
    shell_out!("rpm -qa | grep chef_rpm | xargs -r rpm -e")
  end

  after(:all) do
    shell_out!("rpm -qa | grep chef_rpm | xargs -r rpm -e")
    FileUtils.rm_f "/etc/yum.repos.d/chef-yum-localtesting.repo"
  end

  let(:package_name) { "chef_rpm" }
  let(:yum_package) { Chef::Resource::YumPackage.new(package_name, run_context) }

  describe ":install" do
    context "vanilla use case" do
      let(:package_name) { "chef_rpm" }

      it "installs if the package is not installed" do
        flush_cache
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "does not install if the package is installed" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "does not install twice" do
        flush_cache
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "does not install if the prior version package is installed" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "does not install if the i686 package is installed" do
        skip "FIXME: do nothing, or install the x86_64 version?"
        preinstall("chef_rpm-1.10-1.fc24.i686.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.i686$")
      end

      it "does not install if the prior version i686 package is installed" do
        skip "FIXME: do nothing, or install the x86_64 version?"
        preinstall("chef_rpm-1.2-1.fc24.i686.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.i686$")
      end
    end

    context "with versions or globs in the name" do
      it "works with a version" do
        flush_cache
        yum_package.package_name("chef_rpm-1.10")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "works with an older version" do
        flush_cache
        yum_package.package_name("chef_rpm-1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "works with an evr" do
        flush_cache
        yum_package.package_name("chef_rpm-0:1.2-1.fc24")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "works with a version glob" do
        flush_cache
        yum_package.package_name("chef_rpm-1*")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "works with a name glob + version glob" do
        flush_cache
        yum_package.package_name("chef_rp*-1*")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end
    end

    # version only matches the actual yum version, does not work with epoch or release or combined evr
    context "with version property" do
      it "matches the full version" do
        flush_cache
        yum_package.package_name("chef_rpm")
        yum_package.version("1.10")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "matches with a glob" do
        # we are unlikely to ever fix this.  if you've found this comment you should use e.g. "tcpdump-4*" in
        # the name field rather than trying to use a name of "tcpdump" and a version of "4*".
        pending "this does not work, is not easily supported by the underlying yum libraries, but does work in the new dnf_package provider"
        flush_cache
        yum_package.package_name("chef_rpm")
        yum_package.version("1*")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "matches the vr" do
        flush_cache
        yum_package.package_name("chef_rpm")
        yum_package.version("1.10-1.fc24")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "matches the evr" do
        flush_cache
        yum_package.package_name("chef_rpm")
        yum_package.version("0:1.10-1.fc24")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "matches with a vr glob" do
        pending "doesn't work on command line either"
        flush_cache
        yum_package.package_name("chef_rpm")
        yum_package.version("1.10-1*")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "matches with an evr glob" do
        pending "doesn't work on command line either"
        flush_cache
        yum_package.package_name("chef_rpm")
        yum_package.version("0:1.10-1*")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end
    end

    context "downgrades" do
      it "just work with DNF" do
        pending "doesn't work on yum command line either"
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.version("1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "throws a deprecation warning with allow_downgrade" do
        Chef::Config[:treat_deprecation_warnings_as_errors] = false
        #expect(Chef).to receive(:deprecated).with(:dnf_package_allow_downgrade, /^the allow_downgrade property on the dnf_package provider is not used/)
        pending "doesn't work on yum command line either"
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.version("1.2")
        yum_package.run_action(:install)
        yum_package.allow_downgrade true
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end
    end

    context "with arches" do
      it "installs with 64-bit arch in the name" do
        flush_cache
        yum_package.package_name("chef_rpm.x86_64")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "installs with 32-bit arch in the name" do
        flush_cache
        yum_package.package_name("chef_rpm.i686")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.i686$")
      end

      it "installs with 64-bit arch in the property" do
        flush_cache
        yum_package.package_name("chef_rpm")
        yum_package.arch("x86_64")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "installs with 32-bit arch in the property" do
        flush_cache
        yum_package.package_name("chef_rpm")
        yum_package.arch("i686")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.i686$")
      end
    end

    context "with constraints" do
      it "with nothing installed, it installs the latest version" do
        flush_cache
        yum_package.package_name("chef_rpm >= 1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "when it is met, it does nothing" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.package_name("chef_rpm >= 1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "when it is met, it does nothing" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.package_name("chef_rpm >= 1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "with nothing intalled, it installs the latest version" do
        flush_cache
        yum_package.package_name("chef_rpm > 1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "when it is not met by an installed rpm, it upgrades" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.package_name("chef_rpm > 1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "when it is met by an installed rpm, it does nothing" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.package_name("chef_rpm > 1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "when there is no solution to the contraint" do
        flush_cache
        yum_package.package_name("chef_rpm > 2.0")
        expect { yum_package.run_action(:install) }.to raise_error(Chef::Exceptions::Package, /No candidate version available/)
      end

      it "when there is no solution to the contraint but an rpm is preinstalled" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.package_name("chef_rpm > 2.0")
        expect { yum_package.run_action(:install) }.to raise_error(Chef::Exceptions::Package, /No candidate version available/)
      end
    end

    context "with source arguments" do
      it "raises an exception when the package does not exist" do
        flush_cache
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/this-file-better-not-exist.rpm")
        expect { yum_package.run_action(:install) }.to raise_error(Chef::Exceptions::Package, /No candidate version available/)
      end

      it "does not raise a hard exception in why-run mode when the package does not exist" do
        Chef::Config[:why_run] = true
        flush_cache
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/this-file-better-not-exist.rpm")
        yum_package.run_action(:install)
        expect { yum_package.run_action(:install) }.not_to raise_error
      end

      it "installs the package when using the source argument" do
        flush_cache
        yum_package.name "something"
        yum_package.package_name "somethingelse"
        yum_package.source("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "installs the package when the name is a path to a file" do
        flush_cache
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "does not downgrade the package with :install" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "does not upgrade the package with :install" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "is idempotent when the package is already installed" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end
    end

    context "with no available version" do
      it "works when a package is installed" do
        FileUtils.rm_f "/etc/yum.repos.d/chef-yum-localtesting.repo"
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "works with a local source" do
        FileUtils.rm_f "/etc/yum.repos.d/chef-yum-localtesting.repo"
        flush_cache
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end
    end

    context "multipackage with arches" do
      it "installs two rpms" do
        flush_cache
        yum_package.package_name([ "chef_rpm.x86_64", "chef_rpm.i686" ] )
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.x86_64$/)
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.i686$/)
      end

      it "does nothing if both are installed" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm", "chef_rpm-1.10-1.fc24.i686.rpm")
        flush_cache
        yum_package.package_name([ "chef_rpm.x86_64", "chef_rpm.i686" ] )
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
      end

      it "installs the second rpm if the first is installed" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.package_name([ "chef_rpm.x86_64", "chef_rpm.i686" ] )
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.x86_64$/)
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.i686$/)
      end

      it "installs the first rpm if the second is installed" do
        preinstall("chef_rpm-1.10-1.fc24.i686.rpm")
        yum_package.package_name([ "chef_rpm.x86_64", "chef_rpm.i686" ] )
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.x86_64$/)
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.i686$/)
      end

      # unlikely to work consistently correct, okay to deprecate the arch-array in favor of the arch in the name
      it "installs two rpms with multi-arch" do
        flush_cache
        yum_package.package_name(%w{chef_rpm chef_rpm} )
        yum_package.arch(%w{x86_64 i686})
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.x86_64$/)
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.i686$/)
      end

      # unlikely to work consistently correct, okay to deprecate the arch-array in favor of the arch in the name
      it "installs the second rpm if the first is installed (muti-arch)" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.package_name(%w{chef_rpm chef_rpm} )
        yum_package.arch(%w{x86_64 i686})
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.x86_64$/)
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.i686$/)
      end

      # unlikely to work consistently correct, okay to deprecate the arch-array in favor of the arch in the name
      it "installs the first rpm if the second is installed (muti-arch)" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.package_name(%w{chef_rpm chef_rpm} )
        yum_package.arch(%w{x86_64 i686})
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.x86_64$/)
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match(/^chef_rpm-1.10-1.fc24.i686$/)
      end

      # unlikely to work consistently correct, okay to deprecate the arch-array in favor of the arch in the name
      it "does nothing if both are installed (muti-arch)" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm", "chef_rpm-1.10-1.fc24.i686.rpm")
        yum_package.package_name(%w{chef_rpm chef_rpm} )
        yum_package.arch(%w{x86_64 i686})
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be false
      end
    end
  end

  describe ":upgrade" do
    context "downgrades" do
      it "just work with DNF" do
        pending "doesn't work on yum command line either"
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.version("1.2")
        yum_package.run_action(:install)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "throws a deprecation warning with allow_downgrade" do
        Chef::Config[:treat_deprecation_warnings_as_errors] = false
        #expect(Chef).to receive(:deprecated).with(:dnf_package_allow_downgrade, /^the allow_downgrade property on the dnf_package provider is not used/)
        pending "doesn't work on yum command line either"
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.version("1.2")
        yum_package.run_action(:install)
        yum_package.allow_downgrade true
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end
    end

    context "with source arguments" do
      it "installs the package when using the source argument" do
        flush_cache
        yum_package.name "something"
        yum_package.package_name "somethingelse"
        yum_package.source("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:upgrade)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "installs the package when the name is a path to a file" do
        flush_cache
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:upgrade)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "downgrades the package" do
        pending "doesn't work on yum command line either"
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:upgrade)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "upgrades the package" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.run_action(:upgrade)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end

      it "is idempotent when the package is already installed" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:upgrade)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end
    end

    context "with no available version" do
      it "works when a package is installed" do
        FileUtils.rm_f "/etc/yum.repos.d/chef-yum-localtesting.repo"
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:upgrade)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end

      it "works with a local source" do
        FileUtils.rm_f "/etc/yum.repos.d/chef-yum-localtesting.repo"
        flush_cache
        yum_package.package_name("#{CHEF_SPEC_ASSETS}/yumrepo/chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:upgrade)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.x86_64$")
      end
    end
  end

  describe ":remove" do
    context "vanilla use case" do
      let(:package_name) { "chef_rpm" }
      it "does nothing if the package is not installed" do
        flush_cache
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end

      it "removes the package if the package is installed" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end

      it "does not remove the package twice" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end

      it "removes the package if the prior version package is installed" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end

      it "removes the package if the i686 package is installed" do
        skip "FIXME: should this be fixed or is the current behavior correct?"
        preinstall("chef_rpm-1.10-1.fc24.i686.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end

      it "removes the package if the prior version i686 package is installed" do
        skip "FIXME: should this be fixed or is the current behavior correct?"
        preinstall("chef_rpm-1.2-1.fc24.i686.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end
    end

    context "with 64-bit arch" do
      let(:package_name) { "chef_rpm.x86_64" }
      it "does nothing if the package is not installed" do
        flush_cache
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end

      it "removes the package if the package is installed" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end

      it "removes the package if the prior version package is installed" do
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end

      it "does nothing if the i686 package is installed" do
        preinstall("chef_rpm-1.10-1.fc24.i686.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.i686$")
      end

      it "does nothing if the prior version i686 package is installed" do
        preinstall("chef_rpm-1.2-1.fc24.i686.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be false
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.2-1.fc24.i686$")
      end
    end

    context "with 32-bit arch" do
      let(:package_name) { "chef_rpm.i686" }
      it "removes only the 32-bit arch if both are installed" do
        preinstall("chef_rpm-1.10-1.fc24.x86_64.rpm", "chef_rpm-1.10-1.fc24.i686.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^chef_rpm-1.10-1.fc24.x86_64$")
      end
    end

    context "with no available version" do
      it "works when a package is installed" do
        FileUtils.rm_f "/etc/yum.repos.d/chef-yum-localtesting.repo"
        preinstall("chef_rpm-1.2-1.fc24.x86_64.rpm")
        yum_package.run_action(:remove)
        expect(yum_package.updated_by_last_action?).to be true
        expect(shell_out("rpm -q chef_rpm").stdout.chomp).to match("^package chef_rpm is not installed$")
      end
    end
  end
end
