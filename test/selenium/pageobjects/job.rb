require 'rubygems'
require 'selenium-webdriver'
require 'test/unit'

require File.dirname(__FILE__) + "/build"

class Job
  include Test::Unit::Assertions

  def initialize(driver, base_url, name)
    @driver = driver
    @base_url = base_url
    @name = name
  end

  def name
    @name
  end

  def job_url
    @base_url + "/job/#{@name}"
  end

  def configure_url
    job_url + "/configure"
  end

  def configure(&block)
    @driver.navigate.to(configure_url)

    unless block.nil?
      yield
      save
    end
  end

  def open
    @driver.navigate.to(job_url)
  end

  def queue_build
    @driver.navigate.to(job_url + "/build?delay=0sec")
    # This is kind of silly, but I can't think of a better way to wait for the
    # build to complete
    sleep 5
  end

  def queue_param_build
    build_button = @driver.find_element(:xpath, "//button[text()='Build']")
    ensure_element(build_button,"Param build button")
    build_button.click
  end

  def build(number)
    Build.new(@driver, @base_url, self, number)
  end

  def add_parameter(type,name,value)
    ensure_config_page
    param_check_box = @driver.find_element(:name, "parameterized")
    ensure_element(param_check_box,"Parametrized build check box")
    param_check_box.click
    param_type_list = @driver.find_element(:xpath, "//button[text()='Add Parameter']")
    ensure_element(param_type_list,"Parameter type list")
    param_type_list.click
    param_type_link = @driver.find_element(:link,type)
    ensure_element(param_type_link,"Link to parameter fo type '#{type}'")
    param_type_link.click
    param_name = @driver.find_element(:xpath, "//input[@name='parameter.name']")
    ensure_element(param_name,"Parameter name")
    param_name.send_keys name
    param_def_value = @driver.find_element(:xpath, "//input[@name='parameter.defaultValue']")
    ensure_element(param_def_value,"Parameter default value")
    param_def_value.send_keys value
  end


  def disable
    assert_equal @driver.current_url, configure_url, "Cannot disableif I'm not on the configure page!"

    checkbox = @driver.find_element(:xpath, "//input[@name='disable']")
    assert_not_nil checkbox, "Couldn't find the disable button on the configuration page"
    checkbox.click
  end

  def allow_concurent_builds
    ensure_config_page
    checkbox = @driver.find_element(:xpath, "//input[@name='_.concurrentBuild']")
    ensure_element(checkbox,"Execute concurrent builds if necessary")
    checkbox.click
  end

  def tie_to(expression)
    restrict = @driver.find_element(:xpath,"//input[@name='hasSlaveAffinity']")
    ensure_element(restrict,"Restrict where this project can be run")
    restrict.click
    restrict.click
    label_exp = @driver.find_element(:xpath,"//input[@name='_.assignedLabelString']");
    ensure_element(label_exp,"Label Expression")
    label_exp.send_keys expression
  end

  def setup_svn(repo_url)
    ensure_config_page
    radio = @driver.find_element(:xpath,"//input[@id='radio-block-24']")
    ensure_element(radio,"SVN radio button")
    radio.click
    remote_loc = @driver.find_element(:xpath,"//input[@id='svn.remote.loc']")
    ensure_element(remote_loc,"Repository URL")
    remote_loc.send_keys repo_url
  end

  def add_build_step(script)
    assert_equal @driver.current_url, configure_url, "Cannot configure build steps if I'm not on the configure page"

    add_step = @driver.find_element(:xpath, "//button[text()='Add build step']")
    assert_not_nil add_step, "Couldn't find the 'Add build step' button"
    add_step.click

    exec_shell = @driver.find_element(:xpath, "//a[text()='Execute shell']")
    assert_not_nil exec_shell, "Couldn't find the 'Execute shell' link"
    exec_shell.click

    # We need to give the textarea a little bit of time to show up, since the
    # JavaScript doesn't seem to make it appear "immediately" as far as the web
    # driver is concerned
    textarea = nil
    Selenium::WebDriver::Wait.new(:timeout => 10).until do
      textarea = @driver.find_element(:xpath, "//textarea[@name='command']")
      textarea
    end

    assert_not_nil textarea, "Couldn't find the command textarea on the page"
    textarea.send_keys script
  end

  def add_ant_build_step(ant_targets,ant_build_file)
    ensure_config_page
    add_step = @driver.find_element(:xpath, "//button[text()='Add build step']")
    ensure_element(add_step,"Add build step")
    add_step.click
    
    exec_ant = @driver.find_element(:xpath, "//a[text()='Invoke Ant']")
    ensure_element(exec_ant,"Invoke Ant")
    exec_ant.click
    
    # choose latest ant version
    ant = nil
    Selenium::WebDriver::Wait.new(:timeout => 10).until do
      ant = @driver.find_element(:name => "ant.antName")
      ant
    end
    ensure_element(ant,"Ant version")
    ant.click
    #TODO cannot find any select equivalent in Ruby API
    ant.send_keys :arrow_down
    ant.click

    # setup ant targets
    targets = nil
    Selenium::WebDriver::Wait.new(:timeout => 10).until do
      targets = @driver.find_element(:xpath, "//input[@name='_.targets']")
      targets
    end
    ensure_element(targets,"Ant targets")
    targets.send_keys ant_targets
    
    # advanced section
    advanced = @driver.find_element(:xpath, "//div[@name='builder']//button[text()='Advanced...']")
    ensure_element(advanced,"Ant advanced")
    advanced.click

    # setup build file
    build_file = nil
    Selenium::WebDriver::Wait.new(:timeout => 10).until do
      build_file = @driver.find_element(:xpath, "//input[@id='textarea._.buildFile']")
      build_file
    end
    ensure_element(build_file,"Ant build file")
    build_file.send_keys ant_build_file

  end

  def wait_for_build(*args)
    number = 1
    if args.size == 1
      number = args[0]
    end
    build = self.build(number)   
    start = Time.now
    while (build.in_progress? && ((Time.now - start) < Build::BUILD_TIMEOUT))
      sleep 5
    end
  end

  def save
    assert_equal @driver.current_url, configure_url, "Cannot save if I'm not on the configure page!"

    button = @driver.find_element(:xpath, "//button[text()='Save']")
    assert_not_nil button, "Couldn't find the Save button on the configuration page"
    button.click
  end
  
  def ensure_config_page
    assert_equal @driver.current_url, configure_url, "Cannot configure build steps if I'm not on the configure page"
  end

  def ensure_element(element,name)
    assert_not_nil element, "Couldn't find element '#{name}'"
  end
    

end
