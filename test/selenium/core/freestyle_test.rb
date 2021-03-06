require File.dirname(__FILE__) + "/../lib/base"
require File.dirname(__FILE__) + "/../pageobjects/newjob"
require File.dirname(__FILE__) + "/../pageobjects/job"
require File.dirname(__FILE__) + "/../pageobjects/newslave"
require File.dirname(__FILE__) + "/../pageobjects/slave"
require File.dirname(__FILE__) + "/../pageobjects/globalconfig"

class FreestyleJobTests < JenkinsSeleniumTest
  def setup
    super
    @job_name = "Selenium_Test_Job"
    NewJob.create_freestyle(@driver, @base_url, @job_name)
    @job = Job.new(@driver, @base_url, @job_name)
  end

  def test_disable_job
    go_home

    @job.configure do
      @job.disable
    end

    # Let's open up the job page and verify that Jenkins says it's disabled
    @job.open

    enable_button = @driver.find_element(:xpath, "//button[text()='Enable']")
    assert_not_nil enable_button, "Couldn't find the [Enable] button, guess we failed to disable the job!"
  end

  def test_exec_shell_build_step
    @job.configure do
      @job.add_build_step "ls"
    end

    @job.queue_build

    build = @job.build(1)

    assert build.succeeded?, "The build did not succeed!"

    assert_not_nil build.console.match("\\+ ls"), "Could not verify that the script ran in the following console: #{build.console}"
  end

  def test_exec_param_build
    @PARAM_NAME = "TEST_PARAM"
    @PARAM_VALUE = "test_value"
    #setup parameter and show it value in shell build step
    @job.configure do
      @job.add_parameter("String Parameter",@PARAM_NAME,@PARAM_VALUE)
      @job.add_build_step("echo $#{@PARAM_NAME}")
    end
    @job.queue_build
    @job.queue_param_build
    @job.wait_for_build
    build = @job.build(1)
    assert build.succeeded? "The build did not succeed!"
    #assert build.console.include? @PARAM_VALUE, "Test parameter value not found!" # requires ruby 1.9
    assert_not_nil build.console.index(@PARAM_VALUE), "Test parameter value not found!"
  end

  def test_concurent_builds
    @job.configure do
      @job.allow_concurent_builds
      @job.add_build_step "sleep 20"
    end
    
    @job.queue_build
    # schedule another build while the first one is running and again wait for a while to ensure that
    # also secod build is running
    @job.queue_build
    sleep 5

    # check if both builds are running a the same time
    build1 = @job.build(1)
    build2 = @job.build(2)
    assert(build1.in_progress?,"Build #1 is not running!")
    assert(build2.in_progress?,"Build #2 is not running!")
    
    # wait for the build to succeed
    @job.wait_for_build
    @job.wait_for_build
    assert build1.succeeded?, "The build #1 did not succeed!"
    assert build2.succeeded?, "The build #2 did not succeed!"
  end
  
  def test_tie_to_label
    @slave_name = "test_slave"
    @test_label = "test_label"

    # create new slave
    NewSlave.create_dumb(@driver, @base_url, @slave_name)
    @slave = Slave.new(@driver, @base_url, @slave_name)
    @slave.set_num_executors(1)
    @slave.set_remote_fs(@slave_tempdir)
    @slave.set_labels(@test_label)
    @slave.set_command_on_master("java -jar #{JENKINS_LIB_DIR}/slave.jar")
    @slave.save
    #wait for slave to be online
    start = Time.now
    while (@slave.is_offline && ((Time.now - start) < TIMEOUT))
      sleep 1
    end
    #TODO throw some exception if the slave is not start in time

    # tie job to the label
    @job.configure do
      @job.tie_to(@test_label)
    end

    # run the job and check where it run
    @job.queue_build
    @job.wait_for_build
    build = @job.build(1)
    check_string = "Building remotely on #{@slave_name}"
    assert_not_nil build.console.index(check_string), "Test wasn't run on #{@slave_name}"

  end

  def test_svn_checkout
    @job.configure do
      # checkout some small project from SVN
      @job.setup_svn("https://svn.jenkins-ci.org/trunk/hudson/plugins/zfs/")
      # check workspace if '.svn' dir is present, if not, fail the job
      @job.add_build_step "if [ '$(ls .svn)' ]; then \n exit 0 \n else \n exit 1 \n fi"
      sleep 10
    end

    @job.queue_build
    @job.wait_for_build
    build = @job.build(1)
    #build should fail if the project is not checked out. 
    #TODO any better way how to check it? Check if all file from repo are present?
    assert build.succeeded?, "The build did not succeed!"

  end

  def test_ant_build_step
    # add latest ant installation
    conf = GlobalConfig.instance
    conf.configure do
      conf.add_ant_latest
    end

    # add ant build step
    @job.configure do
      @job.add_build_step("echo '<project default=\"hello\"><target name=\"hello\"><echo message=\"Hello, World\"/></target></project>' > build.xml ")
      @job.add_ant_build_step("hello","build.xml")
    end

    @job.queue_build
    @job.wait_for_build
    build = @job.build(1)
    assert build.succeeded?, "The build did not succeed!"
  end
  
end
