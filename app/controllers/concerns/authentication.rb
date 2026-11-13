module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || home_url_for(Current.user)
    end

    # Invited students and the owner land on Today; course buyers on the store.
    def home_url_for(user)
      user&.portal_member? ? portal_url : store_url
    end

    # A sign-in or sign-up link may say where to go afterwards (the course
    # someone was about to buy). Only paths on this site are kept.
    def remember_return_to(path)
      path = path.to_s
      session[:return_to_after_authenticating] = path if path.match?(%r{\A/[^/\\]}) && !path.match?(/[\r\n]/)
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
