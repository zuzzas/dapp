require_relative '../spec_helper'

describe Dapp::Builder::Chef do
  include SpecHelpers::Common
  include SpecHelpers::Application

  before :all do
    init_project
  end

  it "builds project" do
    application_build!
    stages.each {|_, stage| expect(stage.image.exist?).to be(true)}
    TEST_FILE_NAMES.each {|name| expect(send("#{name}_exist?")).to be(true)}
  end

  [%i(infra_install foo pizza),
   %i(app_install bar taco),
   %i(infra_setup baz burger),
   %i(app_setup qux pelmeni),
  ].each do |stage, file1, file2|
    it "rebuilds from stage #{stage}" do
      old_template_file_values = {}
      old_template_file_values[file1] = send(file1)
      old_template_file_values[file2] = send(file2)

      new_file_values = {}
      new_file_values[file1] = SecureRandom.uuid
      testproject_path.join("files/#{stage}/#{file1}.txt").tap do |path|
        path.write "#{new_file_values[file1]}\n"
      end
      new_file_values[file2] = SecureRandom.uuid
      mdapp_test_path.join("files/#{stage}/#{file2}.txt").tap do |path|
        path.write "#{new_file_values[file2]}\n"
      end

      application_rebuild!

      expect(send(file1, reload: true)).not_to eq(old_template_file_values[file1])
      expect(send(file2, reload: true)).not_to eq(old_template_file_values[file2])

      expect(send("testproject_#{stage}", reload: true)).to eq(new_file_values[file1])
      expect(send("mdapp_test_#{stage}", reload: true)).to eq(new_file_values[file2])
    end
  end

  def config
    @config ||= {
      name: 'testproject',
      type: :chef,
      from: 'ubuntu:14.04',
      home_path: testproject_path.to_s,
    }
  end

  def project_path
    @project_path ||= Pathname("/tmp/dapp-test-#{SecureRandom.uuid}")
  end

  def testproject_path
    project_path.join('testproject')
  end

  def mdapp_test_path
    project_path.join('mdapp-test')
  end

  def template_testproject_path
    @template_testproject_path ||= Pathname('spec/chef/testproject')
  end

  def template_mdapp_test_path
    @template_mdapp_test_path ||= Pathname('spec/chef/mdapp-test')
  end

  def init_project
    FileUtils.cp_r template_testproject_path, testproject_path.tap {|p| p.parent.mkpath}
    FileUtils.cp_r template_mdapp_test_path, mdapp_test_path.tap {|p| p.parent.mkpath}
  end

  TEST_FILE_NAMES = %i(foo bar baz qux burger pizza taco pelmeni
                       testproject_infra_install testproject_app_install
                       testproject_infra_setup testproject_app_setup
                       mdapp_test_infra_install mdapp_test_app_install
                       mdapp_test_infra_setup mdapp_test_app_setup)

  TEST_FILE_NAMES.each do |name|
    define_method(name) do |reload: false|
      (!reload && instance_variable_get("@#{name}")) ||
        instance_variable_set("@#{name}",
          shellout!("docker run --rm #{application.last_stage.image.name} cat /#{name}.txt").stdout.strip)
    end

    define_method("#{name}_exist?") do
      res = shellout("docker run --rm #{application.last_stage.image.name} ls /#{name}.txt")
      return true if res.exitstatus == 0
      return false if res.exitstatus == 2
      res.error!
    end
  end
end