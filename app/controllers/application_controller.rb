# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ApplicationController < ActionController::Base
  include ::LoginSystem
  protect_from_forgery :only => [:edit, :update, :delete]
  
  before_filter :reset_local_cache, :fire_triggers, :load_lang
  after_filter :reset_local_cache

  class << self
    unless self.respond_to? :template_root
      def template_root
        ActionController::Base.view_paths.last
      end
    end

    # Log all path in file path_cache in Rails.root
    # When we sweep all cache. We just need delete this file
    def cache_page_with_log_page(content, path)
      return unless perform_caching
      cache_page_without_log_page(content, path)
    end
    alias_method_chain :cache_page, :log_page
  end

  protected

  def setup_themer
    # Ick!
    self.view_paths = ::ActionController::Base.view_paths.dup.unshift("#{RAILS_ROOT}/themes/#{this_blog.theme}/views")
  end

  def error(message = "Record not found...", options = { })
    @message = message.to_s
    render :template => 'articles/error', :status => options[:status] || 404
  end

  def fire_triggers
    Trigger.fire
  end

  def load_lang
    # FIXME Provide a caching compatible and SEO frendly way of mulitlanguality. Options for setting the Locale: from the Domain Name (or Subdomain) (example.pl, pl.example.com), setting from an URL path (example.com/en/).
    # TODO (maybe) Add Accept-Language HTTP header support
    # TODO (maybe) Add user profile setting support
    if fetch_langs.include?(params[:locale])
      # Take the setting from an URL param (example.com?locale=en_US)
      # NOTICE This won't work with cacheing
      lang = params[:locale]
      add_to_cookies(:locale, params[:locale], "/")
    elsif fetch_langs.include?(cookies[:locale])
      # NOTICE This won't work with cacheing
      # take the seeting from a cookie
      lang = cookies[:locale]
    else
      # take the default blog language
      lang = this_blog.lang
    end
    Localization.lang = lang
    # Check if for example "en_UK" locale exesists if not check for "en" locale
    if I18n.available_locales.include?(lang.to_sym)
      I18n.locale = lang
    elsif I18n.available_locales.include?(lang[0..1].to_sym)
      I18n.locale = lang[0..1]
    end
    # _("Localization.rtl") 
  end

  def reset_local_cache
    if !session
      session :session => new
    end
    @current_user = nil
  end

  # Helper method to get the blog object.
  def this_blog
    @blog ||= Blog.default
  end

  helper_method :this_blog

  # The base URL for this request, calculated by looking up the URL for the main
  # blog index page.
  def blog_base_url
    url_for(:controller => '/articles').gsub(%r{/$},'')
  end

  def add_to_cookies(name, value, path=nil, expires=nil)
    cookies[name] = { :value => value, :path => path || "/#{controller_name}",
                       :expires => 6.weeks.from_now }
  end

  private

  # TODO Move this to a lib
  # TODO Use this in app/hellpers/admin/settings_helper.rb
  def fetch_langs
    require 'find'
    langs = []
    Find.find(File.join(RAILS_ROOT, "lang")) do |lang|
      if lang =~ /\.rb$/
        langs << File.basename(lang).gsub(".rb", '')
      end
    end
    langs
  end
end

