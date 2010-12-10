#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe StatusMessagesController do
  render_views

  let!(:user) { make_user }
  let!(:aspect) { user.aspects.create(:name => "AWESOME!!") }

  let!(:user2) { make_user }
  let!(:aspect2) { user2.aspects.create(:name => "WIN!!") }

  before do
    connect_users(user, aspect, user2, aspect2)
    request.env["HTTP_REFERER"] = ""
    sign_in :user, user
    @controller.stub!(:current_user).and_return(user)
  end

  describe '#show' do
    before do
      @video_id = "ABYnqp-bxvg"
      @url="http://www.youtube.com/watch?v=#{@video_id}&a=GxdCwVVULXdvEBKmx_f5ywvZ0zZHHHDU&list=ML&playnext=1"
    end
    it 'renders posts with youtube urls' do
      message = user.build_post :status_message, :message => @url, :to => aspect.id
      message[:youtube_titles]= {@video_id => "title"}
      message.save!
      user.add_to_streams(message, aspect.id)
      user.dispatch_post message, :to => aspect.id
      get :show, :id => message.id
      response.body.should match /Youtube: title/
    end
    it 'renders posts with comments with youtube urls' do
      message = user.post :status_message, :message => "Respond to this with a video!", :to => aspect.id
      @comment = user.comment "none", :on => message
      @comment.text = @url
      @comment[:youtube_titles][@video_id] = "title"
      @comment.save!
      get :show, :id => message.id
      response.body.should match /Youtube: title/
    end
  end
  describe '#create' do
    let(:status_message_hash) {
      {:status_message =>{
        :public  =>"true", 
        :message =>"facebook, is that you?", 
        :aspect_ids =>"#{aspect.id}"}}
    }
    it 'responds to js requests' do
      post :create, status_message_hash.merge(:format => 'js')
      response.status.should == 201
    end

    it "doesn't overwrite person_id" do
      new_user = make_user
      status_message_hash[:status_message][:person_id] = new_user.person.id
      post :create, status_message_hash
      StatusMessage.find_by_message(status_message_hash[:status_message][:message]).person_id.should == user.person.id
    end

    it "doesn't overwrite id" do
      old_status_message = user.post(:status_message, :message => "hello", :to => aspect.id)
      status_message_hash[:status_message][:id] = old_status_message.id
      lambda {post :create, status_message_hash}.should raise_error /failed save/
      old_status_message.reload.message.should == 'hello'
    end

    it "dispatches all referenced photos" do
      fixture_filename  = 'button.png'
      fixture_name      = File.join(File.dirname(__FILE__), '..', 'fixtures', fixture_filename)

      photo1 = user.build_post(:photo, :user_file=> File.open(fixture_name), :to => aspect.id)
      photo2 = user.build_post(:photo, :user_file=> File.open(fixture_name), :to => aspect.id)

      photo1.save!
      photo2.save!

      hash = status_message_hash
      hash[:photos] = [photo1.id.to_s, photo2.id.to_s]

      user.should_receive(:dispatch_post).exactly(3).times
      post :create, hash
    end
  end
  describe '#destroy' do
    let!(:message) {user.post(:status_message, :message => "hey", :to => aspect.id)}
    let!(:message2) {user2.post(:status_message, :message => "hey", :to => aspect2.id)}

    it 'should let me delete my photos' do
      delete :destroy, :id => message.id
      StatusMessage.find_by_id(message.id).should be_nil
    end

    it 'will not let you destroy posts visible to you' do
      delete :destroy, :id => message2.id
      StatusMessage.find_by_id(message2.id).should_not be_nil
    end

    it 'will not let you destory posts you do not own' do
      delete :destroy, :id => message2.id
      StatusMessage.find_by_id(message2.id).should_not be_nil
    end

  end
end
