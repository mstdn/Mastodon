require 'rails_helper'

RSpec.describe RemoveFromFollowersService, type: :service do
  let(:bob) { Fabricate(:account, username: 'bob') }

  subject { RemoveFromFollowersService.new }

  describe 'local' do
    let(:sender) { Fabricate(:account, username: 'alice') }
 
    before do
      Follow.create(account: sender, target_account: bob)
      subject.call(bob, sender)
    end

    it 'does not create follow relation' do
      expect(bob.followed_by?(sender)).to be false
    end
  end

  describe 'remote ActivityPub' do
    let(:sender) { Fabricate(:account, username: 'alice', domain: 'example.com', protocol: :activitypub, inbox_url: 'http://example.com/inbox') }

    before do
      Follow.create(account: sender, target_account: bob)
      stub_request(:post, sender.inbox_url).to_return(status: 200)
      subject.call(bob, sender)
    end

    it 'does not create follow relation' do
      expect(bob.followed_by?(sender)).to be false
    end

    it 'sends a reject activity' do
      expect(a_request(:post, sender.inbox_url)).to have_been_made.once
    end
  end
end
