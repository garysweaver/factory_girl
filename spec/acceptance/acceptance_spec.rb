require 'spec_helper'
require 'acceptance/acceptance_helper'

describe "integration" do
  before do
    FactoryGirl.define do
      factory :user, :class => 'user' do
        first_name 'Jimi'
        last_name  'Hendrix'
        admin       false
        email {|a| "#{a.first_name}.#{a.last_name}@example.com".downcase }
      end

      factory Post, :default_strategy => :attributes_for do
        name   'Test Post'
        association :author, :factory => :user
      end

      factory :admin, :class => User do
        first_name 'Ben'
        last_name  'Stein'
        admin       true
        sequence(:username) { |n| "username#{n}" }
        email { Factory.next(:email) }
      end

      factory :sequence_abuser, :class => User do
        first_name { Factory.sequence(:email) }
      end

      factory :guest, :parent => :user do
        last_name 'Anonymous'
        username  'GuestUser'
      end

      factory :user_with_callbacks, :parent => :user do
        after_stub   {|u| u.first_name = 'Stubby' }
        after_build  {|u| u.first_name = 'Buildy' }
        after_create {|u| u.last_name  = 'Createy' }
      end

      factory :user_with_inherited_callbacks, :parent => :user_with_callbacks do
        after_stub {|u| u.last_name = 'Double-Stubby' }
      end

      factory :business do
        name 'Supplier of Awesome'
        association :owner, :factory => :user
      end

      sequence :email do |n|
        "somebody#{n}@example.com"
      end
    end
  end

  describe "a generated attributes hash" do
    before do
      @attrs = Factory.attributes_for(:user, :first_name => 'Bill')
    end

    it "should assign all attributes" do
      expected_attrs = [:admin, :email, :first_name, :last_name]
      actual_attrs = @attrs.keys.sort {|a, b| a.to_s <=> b.to_s }
      actual_attrs.should == expected_attrs
    end

    it "should correctly assign lazy, dependent attributes" do
      @attrs[:email].should == "bill.hendrix@example.com"
    end

    it "should override attrbutes" do
      @attrs[:first_name].should == 'Bill'
    end

    it "should not assign associations" do
      Factory.attributes_for(:post)[:author].should be_nil
    end
  end

  describe "a built instance" do
    before do
      @instance = Factory.build(:post)
    end

    it "should not be saved" do
      @instance.should be_new_record
    end

    it "should assign associations" do
      @instance.author.should be_kind_of(User)
    end

    it "should save associations" do
      @instance.author.should_not be_new_record
    end

    it "should not assign both an association and its foreign key" do
      Factory.build(:post, :author_id => 1).author_id.should == 1
    end
  end

  describe "a created instance" do
    before do
      @instance = Factory.create('post')
    end

    it "should be saved" do
      @instance.should_not be_new_record
    end

    it "should assign associations" do
      @instance.author.should be_kind_of(User)
    end

    it "should save associations" do
      @instance.author.should_not be_new_record
    end
  end

  describe "a generated stub instance" do
    before do
      @stub = Factory.stub(:user, :first_name => 'Bill')
    end

    it "should assign all attributes" do
      [:admin, :email, :first_name, :last_name].each do |attr|
        @stub.send(attr).should_not be_nil
      end
    end

    it "should correctly assign attributes" do
      @stub.email.should == "bill.hendrix@example.com"
    end

    it "should override attributes" do
      @stub.first_name.should == 'Bill'
    end

    it "should assign associations" do
      Factory.stub(:post).author.should_not be_nil
    end

    it "should have an id" do
      @stub.id.should > 0
    end

    it "should have unique IDs" do
      @other_stub = Factory.stub(:user)
      @stub.id.should_not == @other_stub.id
    end

    it "should not be considered a new record" do
      @stub.should_not be_new_record
    end

    it "should raise exception if connection to the database is attempted" do
      lambda { @stub.connection }.should raise_error(RuntimeError)
      lambda { @stub.update_attribute(:first_name, "Nick") }.should raise_error(RuntimeError)
      lambda { @stub.reload }.should raise_error(RuntimeError)
      lambda { @stub.destroy }.should raise_error(RuntimeError)
      lambda { @stub.save }.should raise_error(RuntimeError)
      lambda { @stub.increment!(:age) }.should raise_error(RuntimeError)
    end
  end

  describe "an instance generated by a factory with a custom class name" do
    before do
      @instance = Factory.create(:admin)
    end

    it "should use the correct class name" do
      @instance.should be_kind_of(User)
    end

    it "should use the correct factory definition" do
      @instance.should be_admin
    end
  end

  describe "an instance generated by a factory that inherits from another factory" do
    before do
      @instance = Factory.create(:guest)
    end

    it "should use the class name of the parent factory" do
      @instance.should be_kind_of(User)
    end

    it "should have attributes of the parent" do
      @instance.first_name.should == 'Jimi'
    end

    it "should have attributes defined in the factory itself" do
      @instance.username.should == 'GuestUser'
    end

    it "should have attributes that have been overriden" do
      @instance.last_name.should == 'Anonymous'
    end
  end

  describe "an attribute generated by a sequence" do
    before do
      @email = Factory.attributes_for(:admin)[:email]
    end

    it "should match the correct format" do
      @email.should =~ /^somebody\d+@example\.com$/
    end

    describe "after the attribute has already been generated once" do
      before do
        @another_email = Factory.attributes_for(:admin)[:email]
      end

      it "should match the correct format" do
        @email.should =~ /^somebody\d+@example\.com$/
      end

      it "should not be the same as the first generated value" do
        @another_email.should_not == @email
      end
    end
  end

  describe "an attribute generated by an in-line sequence" do
    before do
      @username = Factory.attributes_for(:admin)[:username]
    end

    it "should match the correct format" do
      @username.should =~ /^username\d+$/
    end

    describe "after the attribute has already been generated once" do
      before do
        @another_username = Factory.attributes_for(:admin)[:username]
      end

      it "should match the correct format" do
        @username.should =~ /^username\d+$/
      end

      it "should not be the same as the first generated value" do
        @another_username.should_not == @username
      end
    end
  end

  describe "a factory with a default strategy specified" do
    it "should generate instances according to the strategy" do
      Factory(:post).should be_kind_of(Hash)
    end
  end

  it "should raise Factory::SequenceAbuseError" do
    lambda {
      Factory(:sequence_abuser)
    }.should raise_error(FactoryGirl::SequenceAbuseError)
  end

  describe "an instance with callbacks" do
    it "should run the after_stub callback when stubbing" do
      @user = Factory.stub(:user_with_callbacks)
      @user.first_name.should == 'Stubby'
    end

    it "should run the after_build callback when building" do
      @user = Factory.build(:user_with_callbacks)
      @user.first_name.should == 'Buildy'
    end

    it "should run both the after_build and after_create callbacks when creating" do
      @user = Factory(:user_with_callbacks)
      @user.first_name.should == 'Buildy'
      @user.last_name.should == 'Createy'
    end

    it "should run both the after_stub callback on the factory and the inherited after_stub callback" do
      @user = Factory.stub(:user_with_inherited_callbacks)
      @user.first_name.should == 'Stubby'
      @user.last_name.should == 'Double-Stubby'
    end
  end
end
