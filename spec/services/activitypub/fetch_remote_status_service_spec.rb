require 'rails_helper'

RSpec.describe ActivityPub::FetchRemoteStatusService, type: :service do
  include ActionView::Helpers::TextHelper

  let!(:sender) { Fabricate(:account, domain: 'foo.bar', uri: 'https://foo.bar') }
  let!(:recipient) { Fabricate(:account) }

  let(:existing_status) { nil }

  let(:note) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: "https://foo.bar/@foo/1234",
      type: 'Note',
      content: 'Lorem ipsum',
      attributedTo: ActivityPub::TagManager.instance.uri_for(sender),
    }
  end

  subject { described_class.new }

  before do
    stub_request(:get, 'https://foo.bar/watch?v=12345').to_return(status: 404, body: '')
    stub_request(:get, object[:id]).to_return(body: Oj.dump(object))
  end

  describe '#call' do
    before do
      existing_status
      subject.call(object[:id], prefetched_body: Oj.dump(object))
    end

    context 'with Note object' do
      let(:object) { note }

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.text).to eq 'Lorem ipsum'
      end
    end

    context 'with Video object' do
      let(:object) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: "https://foo.bar/@foo/1234",
          type: 'Video',
          name: 'Nyan Cat 10 hours remix',
          attributedTo: ActivityPub::TagManager.instance.uri_for(sender),
          url: [
            {
              type: 'Link',
              mimeType: 'application/x-bittorrent',
              href: "https://foo.bar/12345.torrent",
            },

            {
              type: 'Link',
              mimeType: 'text/html',
              href: "https://foo.bar/watch?v=12345",
            },
          ],
        }
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.url).to eq "https://foo.bar/watch?v=12345"
        expect(strip_tags(status.text)).to eq "Nyan Cat 10 hours remixhttps://foo.bar/watch?v=12345"
      end
    end

    context 'with Audio object' do
      let(:object) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: "https://foo.bar/@foo/1234",
          type: 'Audio',
          name: 'Nyan Cat 10 hours remix',
          attributedTo: ActivityPub::TagManager.instance.uri_for(sender),
          url: [
            {
              type: 'Link',
              mimeType: 'application/x-bittorrent',
              href: "https://foo.bar/12345.torrent",
            },

            {
              type: 'Link',
              mimeType: 'text/html',
              href: "https://foo.bar/watch?v=12345",
            },
          ],
        }
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.url).to eq "https://foo.bar/watch?v=12345"
        expect(strip_tags(status.text)).to eq "Nyan Cat 10 hours remixhttps://foo.bar/watch?v=12345"
      end
    end

    context 'with Event object' do
      let(:object) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: "https://foo.bar/@foo/1234",
          type: 'Event',
          name: "Let's change the world",
          attributedTo: ActivityPub::TagManager.instance.uri_for(sender)
        }
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.url).to eq "https://foo.bar/@foo/1234"
        expect(strip_tags(status.text)).to eq "Let's change the worldhttps://foo.bar/@foo/1234"
      end
    end

    context 'with wrong id' do
      let(:note) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: "https://real.address/@foo/1234",
          type: 'Note',
          content: 'Lorem ipsum',
          attributedTo: ActivityPub::TagManager.instance.uri_for(sender),
        }
      end

      let(:object) do
        temp = note.dup
        temp[:id] = 'https://fake.address/@foo/5678'
        temp
      end

      it 'does not create status' do
        expect(sender.statuses.first).to be_nil
      end
    end

    context 'with a valid Create activity' do
      let(:object) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: "https://foo.bar/@foo/1234/create",
          type: 'Create',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: note,
        }
      end

      it 'creates status' do
        status = sender.statuses.first

        expect(status).to_not be_nil
        expect(status.uri).to eq note[:id]
        expect(status.text).to eq note[:content]
      end
    end

    context 'with a Create activity with a mismatching id' do
      let(:object) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: "https://foo.bar/@foo/1234/create",
          type: 'Create',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: {
            id: "https://real.address/@foo/1234",
            type: 'Note',
            content: 'Lorem ipsum',
            attributedTo: ActivityPub::TagManager.instance.uri_for(sender),
          },
        }
      end

      it 'does not create status' do
        expect(sender.statuses.first).to be_nil
      end
    end

    context 'when status already exists' do
      let(:existing_status) { Fabricate(:status, account: sender, text: 'Foo', uri: note[:id]) }

      context 'with a Note object' do
        let(:object) { note.merge(updated: '2021-09-08T22:39:25Z') }

        it 'updates status' do
          existing_status.reload
          expect(existing_status.text).to eq 'Lorem ipsum'
          expect(existing_status.edits).to_not be_empty
        end
      end

      context 'with a Create activity' do
        let(:object) do
          {
            '@context': 'https://www.w3.org/ns/activitystreams',
            id: "https://foo.bar/@foo/1234/create",
            type: 'Create',
            actor: ActivityPub::TagManager.instance.uri_for(sender),
            object: note.merge(updated: '2021-09-08T22:39:25Z'),
          }
        end

        it 'updates status' do
          existing_status.reload
          expect(existing_status.text).to eq 'Lorem ipsum'
          expect(existing_status.edits).to_not be_empty
        end
      end
    end
  end
end
