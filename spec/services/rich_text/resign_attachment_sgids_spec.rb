# frozen_string_literal: true

require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job

RSpec.describe RichText::ResignAttachmentSgids do
  let(:question) { create(:question) }
  let(:rich_text) { question.question_text }
  let(:blob) { upload_blob }

  def upload_blob
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/game-pieces.jpg").open,
      filename: "game-pieces.jpg",
      content_type: "image/jpeg"
    )
  end

  def sha1_signer(secret = Rails.application.secret_key_base) = described_class::Sha1Signer.new(secret)

  # The Marshal token Rails 6.1 wrote, not the JSON envelope SignedGlobalID.create writes
  def sha1_sgid(record, secret: Rails.application.secret_key_base) = sha1_signer(secret).call(record)

  def attachment_tag(sgid, url: nil)
    url_attribute = url ? %( url="#{url}") : ""
    %(<action-text-attachment sgid="#{sgid}"#{url_attribute} content-type="image/jpeg" filename="game-pieces.jpg"></action-text-attachment>)
  end

  def store_body(html)
    rich_text.update_column(:body, "<div>#{html}</div>")
    rich_text.reload
  end

  def store_attachment(sgid, url: nil) = store_body(attachment_tag(sgid, url: url))

  def stored_attachment = rich_text.reload.body.fragment.find_all("action-text-attachment").first

  def stored_sgid = stored_attachment["sgid"]

  def stored_url = stored_attachment["url"]

  # The path the upload template hands Trix, host stripped
  def blob_path(blob) = Rails.application.routes.url_helpers.rails_service_blob_path(blob.signed_id, blob.filename)

  # The blob a stored url's signed id resolves to under the current verifier
  def blob_from(url) = ActiveStorage::Blob.find_signed(url.to_s[%r{/blobs/redirect/([^/]+)/}, 1].to_s)

  # As Trix stored it under the previous release, host and signature included
  let(:previous_release_url) { "https://tenjin.outwood.com/rails/active_storage/blobs/previous-signed-id/game-pieces.jpg" }

  context "with an attachment signed under SHA1" do
    before { store_attachment(sha1_sgid(blob)) }

    it "does not resolve beforehand" do
      expect(rich_text.body.attachables).to all(be_a(ActionText::Attachables::MissingAttachable))
    end

    it "resolves again afterwards" do
      described_class.call
      expect(rich_text.reload.body.attachables).to eq([blob])
    end

    it "is signed with the current verifier" do
      described_class.call
      expect(SignedGlobalID.parse(stored_sgid, for: "attachable")).to be_present
    end

    it "leaves the embeds as they were" do
      expect { described_class.call }
        .to not_change(ActiveStorage::Attachment, :count)
        .and not_have_enqueued_job(ActiveStorage::PurgeJob)
    end

    it "reports the count" do
      expect(described_class.call).to have_attributes(success?: true, payload: include(resigned: 1, unverifiable: 0))
    end

    it "gives the editor this release's blob path" do
      described_class.call
      expect(stored_url).to eq(blob_path(blob))
    end

    it "changes nothing on a second run" do
      described_class.call
      expect { described_class.call }.not_to change { rich_text.reload.body.to_html }
      expect(described_class.call.payload).to include(resigned: 0, urls_rewritten: 0)
    end
  end

  context "with an attachment whose url the previous release issued" do
    before { store_attachment(sha1_sgid(blob), url: previous_release_url) }

    it "replaces it with this release's blob path" do
      described_class.call
      expect(stored_url).to eq(blob_path(blob))
    end

    it "counts the url" do
      expect(described_class.call.payload).to include(urls_rewritten: 1)
    end
  end

  context "with an attachment signed under a previous secret" do
    let(:previous_secret) { "previous-secret-key-base" }

    before { store_attachment(sha1_sgid(blob, secret: previous_secret)) }

    it "verifies with that secret and resolves again" do
      described_class.call(old_secret: previous_secret)
      expect(rich_text.reload.body.attachables).to eq([blob])
    end

    it "cannot verify with the current secret" do
      expect(described_class.call).to have_attributes(failure?: true, error: :unverifiable_sgids)
    end
  end

  context "with a remote image beside an attachment to re-sign" do
    let(:remote_image) { %(<action-text-attachment content-type="image/png" url="https://example.com/diagram.png"></action-text-attachment>) }

    before { store_body(attachment_tag(sha1_sgid(blob)) + remote_image) }

    it "re-signs the attachment and leaves the remote image alone" do
      expect(described_class.call).to have_attributes(success?: true, payload: include(resigned: 1, unverifiable: 0))
      expect(rich_text.reload.body.attachables).to match([blob, an_instance_of(ActionText::Attachables::RemoteImage)])
    end
  end

  context "with a row edited after its batch was loaded" do
    let(:other_blob) { upload_blob }

    before do
      store_attachment(sha1_sgid(blob))
      batch_copy = ActionText::RichText.find(rich_text.id)
      relation = ActionText::RichText.where("body LIKE ?", "%sgid=%")
      allow(ActionText::RichText).to receive(:where).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(batch_copy)
      store_attachment(sha1_sgid(other_blob))
    end

    it "rewrites the row as stored, not the batch copy" do
      described_class.call
      expect(rich_text.reload.body.attachables).to eq([other_blob])
    end
  end

  context "with an attachment that already verifies and carries this release's url" do
    before { store_attachment(blob.attachable_sgid, url: blob_path(blob)) }

    it "leaves the body untouched" do
      expect { described_class.call }.not_to change { rich_text.reload.body.to_html }
    end

    it "counts it as already in the target form" do
      expect(described_class.call.payload).to include(already_target: 1, resigned: 0, urls_rewritten: 0)
    end
  end

  context "with an attachment that already verifies but carries the previous release's url" do
    before { store_attachment(blob.attachable_sgid, url: previous_release_url) }

    it "rewrites the url and nothing else" do
      expect { described_class.call }
        .to change { stored_url }.to(blob_path(blob))
        .and not_change { stored_sgid }
    end

    it "counts the url beside the untouched id" do
      expect(described_class.call.payload).to include(already_target: 1, resigned: 0, urls_rewritten: 1)
    end
  end

  context "with an attachment whose record no longer exists" do
    before do
      sgid = sha1_sgid(blob)
      blob.purge
      store_attachment(sgid)
    end

    it "leaves the tag as it was and still succeeds" do
      expect { described_class.call }.not_to change { stored_sgid }
      expect(described_class.call).to have_attributes(success?: true, payload: include(missing: 1))
    end
  end

  context "with an attachment that verifies under neither key" do
    before { store_attachment("not-a-signed-global-id") }

    it "leaves the tag and fails so the operator sees it" do
      expect { described_class.call }.not_to change { stored_sgid }
      expect(described_class.call).to have_attributes(failure?: true, payload: include(unverifiable: 1))
    end
  end

  describe "downgrade" do
    subject(:downgrade) { described_class.call(direction: :downgrade) }

    def sha1_parse(sgid, secret: Rails.application.secret_key_base)
      SignedGlobalID.parse(sgid, for: "attachable", verifier: sha1_signer(secret).verifier)
    end

    context "with an attachment signed by the current verifier" do
      before { store_attachment(blob.attachable_sgid, url: blob_path(blob)) }

      it "keeps the blob attached as an embed and schedules no purge" do
        rich_text.update!(body: rich_text.body)
        expect(rich_text.reload.embeds.blobs).to eq([blob])

        expect { downgrade }
          .to not_change(ActiveStorage::Attachment, :count)
          .and not_change(ActiveStorage::Blob, :count)
          .and not_have_enqueued_job(ActiveStorage::PurgeJob)
        expect(rich_text.reload.embeds.blobs).to eq([blob])
      end

      it "resolves under SHA1 afterwards" do
        downgrade
        expect(sha1_parse(stored_sgid)&.find).to eq(blob)
      end

      it "no longer verifies under the current verifier" do
        downgrade
        expect(SignedGlobalID.parse(stored_sgid, for: "attachable")).to be_nil
      end

      it "writes a self-validated Marshal payload" do
        downgrade
        payload = Marshal.load(Base64.urlsafe_decode64(stored_sgid.split("--").first))
        expect(payload).to eq("gid" => "#{blob.to_gid}?expires_in", "purpose" => "attachable", "expires_at" => nil)
      end

      it "reports the count" do
        expect(downgrade).to have_attributes(success?: true, payload: include(resigned: 1, unverifiable: 0, urls_rewritten: 1))
      end

      it "writes a url the previous release can serve" do
        downgrade
        signed_id = stored_url[%r{\A/rails/active_storage/blobs/redirect/([^/]+)/game-pieces\.jpg\z}, 1]
        payload, digest = signed_id.split("--")
        key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1)
          .generate_key("ActiveStorage")
        expect(digest).to eq(OpenSSL::HMAC.hexdigest("SHA1", key, payload))
        expect(JSON.parse(Base64.strict_decode64(payload)))
          .to eq("_rails" => {"message" => Base64.strict_encode64(Marshal.dump(blob.id)), "exp" => nil, "pur" => "blob_id"})
      end

      it "no longer resolves the url under the current verifier" do
        downgrade
        expect(blob_from(stored_url)).to be_nil
      end
    end

    context "with a previous secret to sign for" do
      let(:previous_secret) { "previous-secret-key-base" }

      before { store_attachment(blob.attachable_sgid) }

      it "signs with that secret's derivation" do
        described_class.call(direction: :downgrade, old_secret: previous_secret)
        expect(sha1_parse(stored_sgid, secret: previous_secret)&.find).to eq(blob)
      end
    end

    context "with an attachment already signed under SHA1, url included" do
      before do
        signed_id = sha1_signer.blob_signed_id(blob)
        store_attachment(sha1_sgid(blob), url: Rails.application.routes.url_helpers.rails_service_blob_path(signed_id, blob.filename))
      end

      it "leaves the body untouched and counts it as already in the target form" do
        expect { downgrade }.not_to change { rich_text.reload.body.to_html }
        expect(downgrade.payload).to include(already_target: 1, resigned: 0, urls_rewritten: 0)
      end
    end

    context "with an attachment that verifies under neither key" do
      before { store_attachment("not-a-signed-global-id") }

      it "leaves the tag and fails" do
        expect { downgrade }.not_to change { stored_sgid }
        expect(downgrade).to have_attributes(failure?: true, payload: include(unverifiable: 1))
      end
    end

    it "round-trips through upgrade and back" do
      store_attachment(sha1_sgid(blob))
      described_class.call
      described_class.call(direction: :downgrade)
      described_class.call
      expect(rich_text.reload.body.attachables).to eq([blob])
      expect(blob_from(stored_url)).to eq(blob)
    end

    it "reproduces the blob id of a production url" do
      # The payload half of the signed id in a real production url for blob
      # 720, which does not depend on the secret
      production_payload = "eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBBdEFDIiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19"
      signed_id = described_class::Sha1Signer.new("any secret").blob_signed_id(ActiveStorage::Blob.new(id: 720))
      expect(signed_id.split("--").first).to eq(production_payload)
    end

    it "reproduces the payload of a production token" do
      # The payload half of a real production token for blob 89, which does not
      # depend on the secret. Its gid embeds the app name from `module Csquiz`.
      production_payload = "BAh7CEkiCGdpZAY6BkVUSSIzZ2lkOi8vY3NxdWl6L0FjdGl2ZVN0b3JhZ2U6OkJsb2IvODk_ZXhwaXJlc19pbgY7AFRJIgxwdXJwb3NlBjsAVEkiD2F0dGFjaGFibGUGOwBUSSIPZXhwaXJlc19hdAY7AFQw"
      token = described_class::Sha1Signer.new("any secret").call(ActiveStorage::Blob.new(id: 89))
      expect(token.split("--").first).to eq(production_payload)
    end
  end

  it "rejects an unknown direction" do
    expect { described_class.new(direction: :sideways) }.to raise_error(ArgumentError, /direction/)
  end
end
