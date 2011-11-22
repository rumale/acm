require File.expand_path("../../spec_helper", __FILE__)

require "rack/test"
require "json"

describe ACM::Controller::RackController do
  include Rack::Test::Methods

  def app
    @app ||= ACM::Controller::RackController.new
  end

  describe "when sending an invalid request for object creation" do

    it "should respond with an error on an incorrectly formatted request" do
      @logger = ACM::Config.logger
      basic_authorize "admin", "password"

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => "object_data" }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")

    end

    it "should respond with an error on an empty request" do
      @logger = ACM::Config.logger
      basic_authorize "admin", "password"

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => nil }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")

    end


  end


  describe "when requesting a new object" do

    before(:each) do
      #Fix the schema
      ps1 = ACM::Models::PermissionSets.new(:name => :app_space.to_s)
      ps1.save
      ps2 = ACM::Models::PermissionSets.new(:name => :director.to_s)
      ps2.save
      ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :read_appspace.to_s).save
      ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :write_appspace.to_s).save
      ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :delete_appspace.to_s).save

      @user1 = SecureRandom.uuid
      @user2 = SecureRandom.uuid
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid

      @logger = ACM::Config.logger
    end

    it "should create a new object and return it's representation" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :id => "54947df8-0e9e-4471-a2f9-9af509fb5889",
        :additionalInfo => "{component => cloud_controller}",
        :meta => {
          :updated => 1273740902,
          :created => 1273726800,
          :schema => "urn:acm:schemas:1.0"
        }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should eql(object_data[:permission_sets])
      body[:additionalInfo].should eql(object_data[:additionalInfo])
      body[:id].should_not be_nil
      body[:id].should_not eql(object_data[:id])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:created].should_not eql(object_data[:meta][:created])
      body[:meta][:updated].should_not eql(object_data[:meta][:updated])
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should create an object with multiple types"

    it "should create an object with no types" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :additionalInfo => "{component => cloud_controller}"
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should be_nil
      body[:additionalInfo].should eql(object_data[:additionalInfo])
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should assign the requested acls to a new object" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additionalInfo => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u:#{@user1}", "u:#{@user2}", "u:#{@user3}", "u:#{@user4}"],
          :write_appspace => ["u:#{@user2}", "u:#{@user3}"],
          :delete_appspace => ["u:#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:acl].should_not be_nil
      sorted_acls = body[:acl].keys().sort()
      sorted_acls.should eql([:read_appspace, :write_appspace, :delete_appspace].sort())

      sorted_users = body[:acl][:read_appspace].sort()
      sorted_users.should eql(["u:#{@user1}", "u:#{@user2}", "u:#{@user3}", "u:#{@user4}"].sort())

      sorted_users = body[:acl][:write_appspace].sort()
      sorted_users.should eql(["u:#{@user2}", "u:#{@user3}"].sort())

      sorted_users = body[:acl][:delete_appspace].sort()
      sorted_users.should eql(["u:#{@user4}"].sort())

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should eql(object_data[:permission_sets])
      body[:additionalInfo].should eql(object_data[:additionalInfo])
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should not allow a permission to be assigned to an object with no types" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :additionalInfo => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u:#{@user1}", "u:#{@user2}", "u:#{@user3}", "u:#{@user4}"],
          :write_appspace => ["u:#{@user2}", "u:#{@user3}"],
          :delete_appspace => ["u:#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")
    end


    it "should assign a permission to an object only if the type allows it" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additionalInfo => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u:#{@user1}", "u:#{@user2}", "u:#{@user3}", "u:#{@user4}"],
          :write_appspace => ["u:#{@user2}", "u:#{@user3}"],
          :update_appspace => ["u:#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")
    end

  end

  describe "when fetching an object" do

    before(:each) do
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                    :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                    :additional_info => "this is the permission set for the app space")

      @permission_set_service.create_permission_set(:name => :director)


      @user1 = SecureRandom.uuid
      @user2 = SecureRandom.uuid
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid

      @logger = ACM::Config.logger
    end

    it "should return the object that's requested" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additionalInfo => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u:#{@user1}", "u:#{@user2}", "u:#{@user3}", "u:#{@user4}"],
          :write_appspace => ["u:#{@user2}", "u:#{@user3}"],
          :delete_appspace => ["u:#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      original_object = last_response.body

      get "/objects/#{body[:id]}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{body[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      fetched_object = last_response.body

      original_object.should eql(fetched_object)

    end

    it "should return an error when the object does not exist" do
      basic_authorize "admin", "password"

      get "/objects/1234", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

    it "should return an error on an invalid request" do
      basic_authorize "admin", "password"

      get "/objects/", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

  end

  describe "when deleting an object" do

    before(:each) do
      #Fix the schema
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                    :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                    :additional_info => "this is the permission set for the app space")

      @permission_set_service.create_permission_set(:name => :director)


      @user1 = SecureRandom.uuid
      @user2 = SecureRandom.uuid
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid

      @logger = ACM::Config.logger
    end

    it "should delete the object that's requested" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additionalInfo => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u:#{@user1}", "u:#{@user2}", "u:#{@user3}", "u:#{@user4}"],
          :write_appspace => ["u:#{@user2}", "u:#{@user3}"],
          :delete_appspace => ["u:#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      delete "/objects/#{body[:id]}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("delete /objects/#{body[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should eql("0")

      get "/objects/#{body[:id]}", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1000)
      body[:description].should include("not found")

      #Should not mess up any other tables. should be able to still create objects
      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additionalInfo => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u:#{@user1}", "u:#{@user2}", "u:#{@user3}", "u:#{@user4}"],
          :write_appspace => ["u:#{@user2}", "u:#{@user3}"],
          :delete_appspace => ["u:#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:acl].should_not be_nil
      sorted_acls = body[:acl].keys().sort()
      sorted_acls.should eql([:read_appspace, :write_appspace, :delete_appspace].sort())

      sorted_users = body[:acl][:read_appspace].sort()
      sorted_users.should eql(["u:#{@user1}", "u:#{@user2}", "u:#{@user3}", "u:#{@user4}"].sort())

      sorted_users = body[:acl][:write_appspace].sort()
      sorted_users.should eql(["u:#{@user2}", "u:#{@user3}"].sort())

      sorted_users = body[:acl][:delete_appspace].sort()
      sorted_users.should eql(["u:#{@user4}"].sort())

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should eql(object_data[:permission_sets])
      body[:additionalInfo].should eql(object_data[:additionalInfo])
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")

    end

    it "should return an error when the object does not exist" do
      basic_authorize "admin", "password"

      delete "/objects/1234", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

    it "should return an error on an invalid request" do
      basic_authorize "admin", "password"

      delete "/objects/", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

  end

end