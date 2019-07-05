# ---------------------------------------------------------------
# name:  discourse-lms-lti
# about: Discourse plugin to authenticate with LTI (eg., for an D2L Brightspace and Instructure Canvas course)
# version: 0.8.0
# author: William Weber
# original_author: MIT Teaching Systems Lab
# url: https://github.com/wlweber/discourse-d2l-lti
# required_version: 1.9.0.beta8
# ---------------------------------------------------------------

# Plugins need to explicitly include their dependencies, and the loading
# mechanism is different than with bundler.
# See https://github.com/discourse/discourse/blob/master/lib/plugin_gem.rb
gem 'ims-lti', '1.1.13', require: false, require_name: 'ims/lti'


# Enable site settings in admin UI.
# See descriptions in files in the `config` folder.
enabled_site_setting :lti_consumer_key
enabled_site_setting :lti_consumer_secret
enabled_site_setting :lti_consumer_authenticate_url


# Register Discourse AuthProvider
require_relative 'lti_strategy.rb'
require_relative 'lti_authenticator.rb'
auth_provider({
  title: 'Click to login with LMS',
  message: 'Click to login with LMS',
  authenticator: LTIAuthenticator.new,
  full_screen_login: true,
  custom_url: '/lti/redirect_to_consumer'
})


# This styles the login button, and overrides #login-form to
# adds a little more separation between the LMS login button and
# the the normal login form below (which is only for admin users).
register_css <<CSS

.btn-social.lti {
  height: 38px;
  font-size: 16px;
  text-align: left;
  color: white;
  background-color: rgb(183, 38, 103);
  background-size: 32px;
  background-repeat: no-repeat;
  background-position-x: 10px;
}

#login-form {
    border-top: 2px solid #eee;
    padding-top: 40px;
}
CSS


# This adds an endpoint that will redirect to the LMS URL.  This code is executed
# after Rails initializes, since it's adding a controller that subclasses
# `ApplicationController`.
#
# The way Discourse AuthProviders typically work, the authentication URL is
# fixed.  Since we want to let admin users use the Discourse Admin UI to set the 
# URL for a particular LMS course, we don't know the redirect URL at plugin boot
# time.  The AuthProvider interface only supports passing in the redirect URL at
# boot time, so we give it our new endpoint, and it will read the LMS URL from
# `SiteSetting` and redirect to that LMS course.
after_initialize do
  PLUGIN_NAME = 'discourse-lms-lti'.freeze
  # It uses an Engine since just drawing the route led to problems with loading the
  # controller class.  This method was drawn from the discourse-poll plugin.
  module ::DiscourseLMSLti
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseLMSLti
    end
  end
  DiscourseLMSLti::Engine.routes.draw do
    get '/redirect_to_consumer' => 'lti#redirect_to_consumer'
  end
  Discourse::Application.routes.append do
    mount ::DiscourseLMSLti::Engine, at: '/lti'
  end

  require_dependency 'application_controller'
  class ::DiscourseLMSLti::LtiController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    # Adapted from Discourse's StaticController#enter
    skip_before_action :check_xhr, :redirect_to_login_if_required, :verify_authenticity_token

    def redirect_to_consumer
      url = SiteSetting.lti_consumer_authenticate_url
      redirect_to url
    end
  end
end