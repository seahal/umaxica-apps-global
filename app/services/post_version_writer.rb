# typed: false
# frozen_string_literal: true

class PostVersionWriter
  def self.write!(post, attrs:, editor: nil)
    version_class =
      case post
      when ComPost then ComPostVersion
      when OrgPost then OrgPostVersion
      when AppPost then AppPostVersion
      else
        raise ArgumentError, "unsupported post type: #{post.class}"
      end

    version_class.create!(
      post.model_name.singular.to_sym => post,
      :permalink => post.permalink,
      :response_mode => post.response_mode,
      :redirect_url => post.redirect_url,
      :publish_at => post.published_at,
      :expires_at => post.expires_at,
      :title => attrs[:title],
      :description => attrs[:description],
      :body => attrs[:body],
      :edited_by_type => editor&.class&.name,
      :edited_by_id => editor&.id,
    )
  end
end
