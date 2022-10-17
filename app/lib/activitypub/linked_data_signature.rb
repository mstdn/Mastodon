# frozen_string_literal: true

class ActivityPub::LinkedDataSignature
  include JsonLdHelper

  CONTEXT = 'https://w3id.org/identity/v1'

  def initialize(json)
    @json = json.with_indifferent_access
  end

  def verify_actor!
    return unless @json['signature'].is_a?(Hash)

    type        = @json['signature']['type']
    creator_uri = @json['signature']['creator']
    signature   = @json['signature']['signatureValue']

    return unless type == 'RsaSignature2017'

    creator   = ActivityPub::TagManager.instance.uri_to_actor(creator_uri)
    creator ||= ActivityPub::FetchRemoteKeyService.new.call(creator_uri, id: false)

    return if creator.nil?

    options_hash   = hash(@json['signature'].without('type', 'id', 'signatureValue').merge('@context' => CONTEXT))
    document_hash  = hash(@json.without('signature'))
    to_be_verified = options_hash + document_hash

    if creator.keypair.public_key.verify(OpenSSL::Digest.new('SHA256'), Base64.decode64(signature), to_be_verified)
      creator
    end
  end

  def sign!(creator, sign_with: nil)
    options = {
      'type'    => 'RsaSignature2017',
      'creator' => ActivityPub::TagManager.instance.key_uri_for(creator),
      'created' => Time.now.utc.iso8601,
    }

    options_hash  = hash(options.without('type', 'id', 'signatureValue').merge('@context' => CONTEXT))
    document_hash = hash(@json.without('signature'))
    to_be_signed  = options_hash + document_hash
    keypair       = sign_with.present? ? OpenSSL::PKey::RSA.new(sign_with) : creator.keypair

    signature = Base64.strict_encode64(keypair.sign(OpenSSL::Digest.new('SHA256'), to_be_signed))

    @json.merge('signature' => options.merge('signatureValue' => signature))
  end

  private

  def hash(obj)
    Digest::SHA256.hexdigest(canonicalize(obj))
  end
end
