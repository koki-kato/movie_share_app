class Video < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  has_one_attached :video

  validates :title, presence:true, uniqueness: { scope: :organization }
  
  # 動画自体はアプリ内には保存されないので、動画なしを不可, 動画以外を不可とするバリデーションはここでは設定しない
  # validates :video, presence: true, blob: { content_type: :video }
  
  scope :user_has, ->(organization_id) { where(organization_id: organization_id) }
  scope :current_user_has, ->(current_user) { where(organization_id: current_user.organization_id) }
  scope :available, -> { where(is_valid: true) }

  def identify_organization_and_user(current_user)
    self.organization_id = current_user.organization.id
    self.user_id = current_user.id
  end

  def my_upload?(current_user)
    return true if self.user_id == current_user.id

    false
  end

  def ensure_owner?(current_user)
    return true if current_user.role == 'owner'

    false
  end

  # 下記vimeoへのアップロード機能
  attr_accessor :video

  before_create :upload_to_vimeo

  def upload_to_vimeo
    # connect to Vimeo as your own user, this requires upload scope
    # in your OAuth2 token
    vimeo_client = VimeoMe2::User.new(ENV['VIMEO_API_TOKEN'])
    # upload the video by passing the ActionDispatch::Http::UploadedFile
    # to the upload_video() method. The data_url in this model, stores
    # the location of the uploaded video on Vimeo.

    # 動画が存在している、拡張子が動画のものであればvimeoにアップロードする
    if self.video.present? && (self.video.content_type == "video/webm" || self.video.content_type == "video/quicktime" || self.video.content_type == "video/MP4" || self.video.content_type == "video/WMV" || self.video.content_type == "video/AVI")
      video = vimeo_client.upload_video(self.video) 
      self.data_url = video['uri']
      return true
    end
  # アプリ側ではなく、vimeo側に原因があるエラーのとき(容量不足など)
  rescue VimeoMe2::RequestFailed => e
    errors.add(:video, e.message)
    return false
  end

  validate :data_url_is_necessary 
  
  def data_url_is_necessary
    # デフォルトでdata_urlがnilならエラーとするのではなく、投稿ボタン押下後にvideo = vimeo_client.upload_video(self.video) がない状況下でdata_urlがnilならエラーとする。
    if video.nil? || ( video.content_type != "video/webm" && video.content_type != "video/quicktime" && video.content_type != "video/MP4" && video.content_type != "video/WMV" && video.content_type != "video/AVI" )
      errors.add(:data_url, "をアップロードしてください")  if data_url == nil 
    end
  end
end