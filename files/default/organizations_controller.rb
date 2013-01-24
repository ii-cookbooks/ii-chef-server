#
# Author:: Nuo Yan (<nuo@opscode.com>)
# Copyright:: Copyright (c) 2010 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class OrganizationsController < ApplicationController

  include GroupsHelper
  include ActionView::Helpers::TagHelper

  skip_before_filter :check_org_association
  skip_before_filter :check_current_environment

  def index
   begin
     @exception_get_orgs=false
     @exception_get_invites=false
     @orgs = Array.new
     begin
       org_list = opscode_server_rest(session[:user], "users").get_rest("#{session[:user]}/organizations").map{|org| org.values.first["name"]}.sort
     rescue Net::HTTPServerException => e
       @exception_get_orgs=true
       if forbidden?(e)
         # can this actually happen?
         Chef::Log.debug("API server returned 403 when requesting the list of orgs for user '#{session[:user]}'\n#{format_exception(e)}")
         @display_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organization-index-403", session[:language])
       else
         Chef::Log.error("Error attempting to list orgs for user '#{session[:user]}'\n#{format_exception(e)}")
         # If we can't get the list of nodes from the API server and it's not 403, things are SRSLY wrong.
         raise
       end
     end
     @orgs = org_list unless org_list.nil?
     @current_org = preferences[:current_org]

     @invites = Array.new
     begin
       invites_raw  = opscode_server_rest(session[:user], "users/#{session[:user]}").get_rest("association_requests")
     rescue Net::HTTPServerException => e
       @exception_get_invites=true
       if forbidden?(e)
         # can this actually happen?
         Chef::Log.debug("API server returned 403 when requesting the list of orgs invites for user '#{session[:user]}'\n#{format_exception(e)}")
         @display_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-index-403", session[:language])
       else
         Chef::Log.error("Error attempting to list org invite for user '#{session[:user]}'\n#{format_exception(e)}")
         raise
       end
     end
     invites_raw.each {|i| @invites.push i}
     @invites.sort! {|a,b| a['orgname'] <=> b['orgname']}

     @prompt_for_create = @current_org.nil? && @orgs.empty? && @invites.empty?
     render
   end
  end

  # PUT to /organizations/:id
  #
  # The only function the organization update endpoint serves is to
  # complete the workflow of organizaiton creation. Once the billing
  # information has been successfully submitted to Charigfy, the
  # client side will update the organization billing plan with the
  # plan selected by the user at creation time. All other organization
  # management activities are now handled by www.opscode.com/account
  #
  def update
    org_data = Hash.new
    org_data[:billing_plan] = params[:billing_plan] if params[:billing_plan]

    begin
      opscode_server_rest(session[:user], "organizations").put_rest("#{params[:id]}", org_data)
      render(:json => {:status => 'success'})
    rescue Net::HTTPServerException => e
      # parse the error message/id from the response body here
      response = JSON.parse(e.response.body)
      error_message = if response['error_id']
                        msg = Mixlib::Localization::Messages.get_message_by_id(response['error_id'], session[:language])
                        Mixlib::Localization::Messages.parse_error_message(msg)
                      else
                        response['error']
                      end

      self.status = if not_found?(e)
                      Chef::Log.debug("API service returned 404 updating organization #{params[:id]}\n#{format_exception(e)}")
                      404
                    elsif forbidden?(e)
                      Chef::Log.debug("API service returned 403 updating organization #{params[:id]}\n#{format_exception(e)}")
                      403
                    elsif bad_request?(e)
                      Chef::Log.debug("API service returned 400 updating organization #{params[:id]}\n#{format_exception(e)}")
                      400
                    else
                      Chef::Log.error("API service returned error updating organization #{params[:id]}\n#{format_exception(e)}")
                      error_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-500", session[:language])
                      500
                    end

      render(:json => {:error => error_message})
    end
  end

  # POST to /organizations/:name/select
  def select
    preferences[:current_org] = params[:id]
    redirect_to :organizations
  end

  # DELETE to /organizations/:name/users/:username
  def dissociate
    org  = params[:id]
    user = params[:user_id]

    # check that the dissociation will not empty the admins groups
    empty_groups = []
    forbidden_groups = []
    %w{admins billing-admins}.each do |group|
      begin
        if groups_empty?(group,:ignore_actors => user, :organization => org)
          empty_groups << group
        end
      rescue GroupPermissionError => e
        empty_groups << group
        forbidden_groups += e.groups
      end
    end

    if !empty_groups.empty?
      error_messages = []
      error_messages << "Unable to dissociate #{content_tag('strong', user)}"
      error_messages << "from #{content_tag('strong', org)}."
      error_messages << "Dissociation of this user will leave the following groups empty:"
      error_messages << (empty_groups.join(', ') << '.')
      if !forbidden_groups.empty?
        error_messages << "The following groups are inaccessible due to read permissions:"
        error_messages << (forbidden_groups.flatten.uniq.join(', ') << '.')
      end
      flash[:error] = error_messages.join(' ').html_safe
      redirect_to(:back) && return
    end

    begin
      opscode_server_rest(session[:user], "organizations/#{org}").delete_rest("users/#{user}")

      # if the user is dissociating themselves from an organization,
      # make sure that organization is no longer their "currenlyt
      # selected' organization.
      if (user == session[:user]) && (org == preferences[:current_org])
        preferences[:current_org] = nil
      end

      # notify the user of a successful dissociation and redirect back
      # to where they were
      flash[:notice] = Mixlib::Localization::Messages.get_parse_info_message('opscode-chef-webui-users-dissociate-success', session[:language])

      # redirect the user back to where they were, unless they were on
      # the 'show users' page, since they will no longer have rights
      # to view that user
      if request.referer.match(/users\/.+$/)
        redirect_to(:users)
      else
        redirect_to(:back)
      end
    rescue Net::HTTPServerException => e
      if not_found?(e)
        Chef::Log.debug("API service returned 404 dissociate: organization #{org}, user #{user}")
        error = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-dissociate-404", session[:language])
      elsif forbidden?(e)
        Chef::Log.debug("API service returned 403 dissociate: organization #{org}, user #{user}")
        error = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-dissociate-403", session[:language])
      else
        Chef::Log.error("API service returned error dissociating organization #{org}, user #{user}\n#{format_exception(e)}")
        raise
      end
      flash[:error] = error
      redirect_to(:organizations)
    end
  end

  # GET to /organizations/associate
  # associate new org
  # this method renders the page
  def associate
    session[:return_to] = :organizations
    render :associate
  end

  # POST to /organizations/_associate
  # this method does the actual association invitation
  def do_associate
    users = params['username'].split(",").each{|u| u.strip!}
    organization = (params['organization'].nil? || params['organization'].empty?) ? preferences[:current_org] : params['organization']

    # here's the deal, we want to exit as soon as we come across some bad juju, so we are going to wrap all the sexy logic
    # in a begin rescue block. when we run into said juju, we're going to throw an exception with a detailed (and localized)
    # error message that we send to the user.
    # this is ugly :( but we have to do this because merb's redirect doesn't get us the f*** out of the action when we call it
    # i'll comment the sh*t out of this bad boy to help all y'alls follow along
    begin
      # the first thing we need to do is check that both of the fields are present in the form
      raise InviteError, Mixlib::Localization::Messages.get_parse_info_message("opscode-chef-webui-organizations-associate-empty-user", session[:language]) if users.nil? || users.empty?
      raise InviteError, Mixlib::Localization::Messages.get_parse_info_message("opscode-chef-webui-organizations-associate-no-org", session[:language]) if organization.nil? || organization.empty?

      # now lets try inviting some of these users to our org
      processed = ""
      users.each do |u|
        begin
          # make a call to the api service
          result = opscode_server_rest(session[:user], "organizations/#{URI.encode(organization)}").post_rest("association_requests", {:user => u})
        rescue Net::HTTPServerException => e
          # something happened, lets try to tell the user what went wrong
          if bad_request?(e)
            Chef::Log.debug("API service returned 400 associate organization with user '#{u}' #{params[:id]}")
            display_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-associate-400", session[:language])
          elsif forbidden?(e)
            Chef::Log.debug("API service returned 403 associate organization with user '#{u}' #{params[:id]}")
            display_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-associate-403", session[:language])
          elsif not_found?(e)
            Chef::Log.debug("API service returned 404 associate organization with user '#{u}' #{params[:id]}")
            display_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-associate-404", session[:language])
          elsif conflict?(e)
            Chef::Log.debug("API service returned 409 associate organization with user '#{u}' #{params[:id]}\n#{format_exception(e)}")
            display_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-associate-409", session[:language])
          end

          # lets let the user know the work we actually did before we died
          base_error_message = "#{Mixlib::Localization::Messages.get_parse_info_message('opscode-chef-webui-organizations-associate-failed-user', session[:language])} #{u}: #{display_message}"

          # get out of here before we cause more damage
          raise InviteError, base_error_message
        else
          # everything is peachy, lets keep track of the work we are doing
          processed.concat("#{u} ")

          # send the email to the user and let them know they are loved
          begin
            org = result['organization']
            org_user = result['organization_user']
            user = result['user']
            if user['email']
              subj = Mixlib::Localization::Messages.get_parse_info_message("opscode-chef-webui-organizations-associate-notify-email-subject", session[:language])
              subj = "#{subj} '#{org['full_name']}'"
              OrganizationInviteMailer.send_invitation(user, org['full_name'], org_user['display_name'], user['email'], subj).deliver
            else
              Chef::Log.error("Unable to send invite email to user #{u}: user has no email address")
            end
          rescue => e
            # so the email failed, but its not critical
            # lets swallow this and move on. nothing to see here kids, but why don't we throw it in the logs for kicks :)
            Chef::Log.error("There was an error sending the invite email to user #{u}\n#{format_exception(e)}")
          end
        end
      end

      # dood! we made it through, lets tell the user
      flash[:notice] = Mixlib::Localization::Messages.get_parse_info_message("opscode-chef-webui-organizations-associate-success", session[:language])
      redirect_to(:users)
    rescue InviteError => ie
      # so we died somewhere along the way... bummer, but since we have InviteError, we kinda expected it
      # lets pull that i18n message out of our beautiful exception that we threw and pass it on to the user
      flash[:error] = ie.message
      redirect_to(:users)
    end
  end


  # POST /organizations/invites/:id/accept
  def accept_invite
    invite_id = params[:id]
    begin
      Chef::Log.debug "users/#{session[:user]}/association_requests/#{invite_id}"
      opscode_server_rest(session[:user], "users/#{session[:user]}").put_rest("association_requests/#{invite_id}", {:response => 'accept'})
      flash[:notice] = Mixlib::Localization::Messages.get_parse_info_message("opscode-chef-webui-organizations-invite-accept", session[:language])
      redirect_to(:organizations)
    rescue Net::HTTPServerException => e
      if not_found?(e)
        error_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-invite-not-found", session[:language])
      elsif forbidden?(e)
        error_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-invite-accept-forbidden", session[:language])
      elsif conflict?(e)
        error_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-invite-accept-already", session[:language])
      else
        Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
        raise e
      end
      flash[:error] = error_message
      redirect_to(:organizations)
    end
  end

  # POST /organizations/invites/:id/reject
  def reject_invite
    invite_id = params[:id]
    begin
      Chef::Log.debug "users/#{session[:user]}/association_requests/#{invite_id}"
      opscode_server_rest(session[:user], "users/#{session[:user]}").put_rest("association_requests/#{invite_id}", {:response => 'reject'})
      flash[:notice] = Mixlib::Localization::Messages.get_parse_info_message("opscode-chef-webui-organizations-invite-reject", session[:language])
      redirect_to(:organizations)
    rescue Net::HTTPServerException => e
      if not_found?(e)
        error_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-invite-not-found", session[:language])
      elsif forbidden?(e)
        error_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-invite-reject-forbidden", session[:language])
      else
        Chef::Log.error("#{e}\n#{e.backtrace.join("\n")}")
        raise e
      end
      flash[:error] = error_message
      redirect_to(:organizations)
    end
  end

  # Generate a sample knife configuration file.
  def generate_knife_config
    org_name = params[:id]
    username = session[:user]

    knife_config_text = <<EOH
current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "#{username}"
client_key               "\#{current_dir}/#{username}.pem"
validation_client_name   "#{org_name}-validator"
validation_key           "\#{current_dir}/#{org_name}-validator.pem"
chef_server_url          "#{Chef::Config[:api_service_url]}/organizations/#{org_name}"
cache_type               'BasicFile'
cache_options( :path => "\#{ENV['HOME']}/.chef/checksums" )
cookbook_path            ["\#{current_dir}/../cookbooks"]
EOH

    send_data(knife_config_text, :filename => 'knife.rb', :type => 'text/plain')
  end

  # Re-generate an organization validation key by sending an update (i.e., PUT) to it
  def regenerate_key
    begin
      # do a GET to retrieve the current full name, etc of the organization
      org_name = params[:id]
      Chef::Log.debug("organizations.regenerate_key: got a request to generate key for #{org_name}")

      @private_key = opscode_server_rest(session[:user], "organizations/#{org_name}/_validator_key").post_rest("", {})['private_key']

      send_data(@private_key, :filename => "#{org_name}-validator.pem", :type => 'application/pem-keys')
    rescue Net::HTTPServerException => e
      if not_found?(e)
        Chef::Log.debug("API service returned 404 regenerating org key #{params[:id]}")
        error = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-regenerate-org-key-404", session[:language])
      elsif forbidden?(e)
        Chef::Log.debug("API service returned 403 regenerating org key #{params[:id]}")
        error = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-regenerate-org-key-403", session[:language])
      else
        Chef::Log.error("API service returned error regenerating key for organization #{params[:id]}\n#{format_exception(e)}")
        raise
      end
      flash[:error] = error
      redirect_to(:organizations)
    end
  end

  def new
    @saved_full_name = session[:saved_full_name]
    @saved_id = session[:saved_id]
    [:saved_full_name, :saved_id].each { |n| session.delete(n) }
    render
  end

  def create
    begin
      # Auto-downcase to simplify things for the user
      params['id'] = params['id'].downcase if params['id']
      # make the organization create call to opscode-account
      body_hash = {
                    :name => params['id'],
                    :full_name => params['full_name'],
                    :org_type => 'Business',
                  }
      Chef::Log.debug "Organizations.create: body hash is : #{body_hash.inspect}"
      opscode_server_rest(Chef::Config[:web_ui_proxy_user],"organizations").post_rest("", body_hash)

      # make an association request for the current user to the new org
      request_body_hash = { :user => session[:user] }
      association_request_response = opscode_server_rest(Chef::Config[:web_ui_proxy_user], "organizations/#{params['id']}").post_rest("association_requests", request_body_hash)
      association_request_id = association_request_response['uri'].split('/').last

      # Accept the association request as the user
      response_body_hash = { :response => 'accept' }
      response = opscode_server_rest(session[:user],"users/#{session[:user]}/association_requests").put_rest(association_request_id, response_body_hash)

      # Add the user to the admins group and the billing admins group
      add_new_user_to_group("admins")
      add_new_user_to_group("billing-admins")

      # Update the billing contact information in Chargify with the creating user's information
      user = opscode_server_rest(Chef::Config[:web_ui_proxy_user], "users").get_rest("#{session[:user]}")
      body_hash = {
        :billing_contact => {
          :first_name => user['first_name'],
          :last_name => user['last_name'],
          :email => user['email']
        }
      }
      opscode_server_rest(session[:user], "organizations").put_rest(params['id'], body_hash)

      # fetch the org object so we can display the chargify url
      get_org(params['id'])

      
      begin
        # This block was added to make sure the opscode user is immediately an admin
        # and also to invite the user to the training organization
        # you could do this on OHC as well, just do the invites/accepts/groups via the webui

        # make an association request for the opscode to the new org
        request_body_hash = { :user => 'opscode' }
        association_request_response = opscode_server_rest(Chef::Config[:web_ui_proxy_user], "organizations/#{params['id']}").post_rest("association_requests", request_body_hash)
        association_request_id = association_request_response['uri'].split('/').last
        # Accept the association request as the opscode
        response_body_hash = { :response => 'accept' }
        response = opscode_server_rest('opscode',"users/opscode/association_requests").put_rest(association_request_id, response_body_hash)
        # Add the user to the admins group and the admins
        add_opscode_to_group("admins")
        
        # make an association request for the current user to the training organziation
        request_body_hash = { :user => session[:user] }
        association_request_response = opscode_server_rest(Chef::Config[:web_ui_proxy_user], "organizations/training").post_rest("association_requests", request_body_hash)
        association_request_id = association_request_response['uri'].split('/').last

        # I thought about creating a new user here
        # new_user = "#{params['id']}-training-workstation"
        # user_hash = {
        #   :username =>     new_user,
        #   :first_name =>   session[:user],
        #   :middle_name =>  '',
        #   :last_name =>    new_user,
        #   :display_name => "#{session[:user]}, #{new_user}",
        #   :email =>        "#{session[:user]}@#{params['id']}.training",
        #   :password =>     'opscode'
        # }
        
        # #begin
        # opscode_server_rest(Chef::Config[:web_ui_proxy_user], "users").post_rest("", user_hash)
        # # make an association request for the opscode to the new org
        # request_body_hash = { :user => new_user }
        # association_request_response = opscode_server_rest(Chef::Config[:web_ui_proxy_user], "organizations/#{params['id']}").post_rest("association_requests", request_body_hash)
        # association_request_id = association_request_response['uri'].split('/').last
        # # Accept the association request as the opscode
        # response_body_hash = { :response => 'accept' }
        # response = opscode_server_rest('opscode',"users/#{new_user}/association_requests").put_rest(association_request_id, response_body_hash)
        # # Add the user to the admins group and the admins
        # add_opscode_to_group("admins")
        # #rescue
        #end
        
      rescue
        nil
      end
      
      # display the json to the webui front-end
      render(:json => {:success => 'success', :chargify_url => chargify_payment_url(@org['chargify_subscription_id'])})
    rescue Net::HTTPServerException => e
      session[:saved_full_name] = params['full_name']
      session[:saved_id] = params['id']
      if forbidden?(e)
        Chef::Log.debug("API service returned 403 creating org #{params['id']}")
        error_message = "Permission denied: You do not have permission to create a new organization."
        self.status = 403
      elsif conflict?(e)
        Chef::Log.debug("Got 409 conflict creating organization #{params['id']}'\n#{format_exception(e)}")
        error_message = "An organization with that short name already exists."
        self.status = 409
      elsif bad_request?(e)
        Chef::Log.debug("Got 400 bad request creating organization #{params['id']}:\n#{format_exception(e)}")
        error_data = JSON.parse(e.response.body)
        error_message = "Error creating organization: #{error_data['error'] || 'unknown error'}"
        self.status = 400
      else
        Chef::Log.error("API service returned error creating organization #{params['id']}\n#{format_exception(e)}")
        error_message = "An application error has occurred. Please try again later."
        self.status = 500
      end
      render(:json =>{:error => error_message})
    end
  end

  # GET to /organizations/:id/_keys
  def keys
    preferences[:current_org] = params['id']
    @_message = { :notice => Mixlib::Localization::Messages.get_parse_info_message("opscode-chef-webui-organizations-create-success", session[:language]) }
    render
  end

  def add_new_user_to_group(groupname)
     # Add the new user to admins, and billing-admins group
      group = opscode_server_rest(Chef::Config[:web_ui_proxy_user], "organizations/#{params['id']}").get_rest("groups/#{groupname}")
      update_body_hash = {
        :groupname => "#{groupname}",
        :actors => {
          "users" => group["actors"].concat([session[:user]]), #.concat(['opscode']),
          "groups" => group["groups"]
        }
      }
      opscode_server_rest(Chef::Config[:web_ui_proxy_user], "organizations/#{params['id']}").put_rest("groups/#{groupname}", update_body_hash)
  end

  def add_opscode_to_group(groupname)
     # Add the new user to admins, and billing-admins group
      group = opscode_server_rest(Chef::Config[:web_ui_proxy_user], "organizations/#{params['id']}").get_rest("groups/#{groupname}")
      update_body_hash = {
        :groupname => "#{groupname}",
        :actors => {
          "users" => group["actors"].concat(['opscode']),
          "groups" => group["groups"]
        }
      }
      opscode_server_rest(Chef::Config[:web_ui_proxy_user], "organizations/#{params['id']}").put_rest("groups/#{groupname}", update_body_hash)
  end

  # we need our own exception class to throw and catch in the do_associate action
  class InviteError < StandardError
  end

  def get_org(org_id)
    begin
      @org = opscode_server_rest(session[:user], "organizations").get_rest(org_id)
    rescue Net::HTTPServerException => e
      @exception = true
      if not_found?(e)
        Chef::Log.debug("API service returned 404 attempting to show org #{org_id}\n#{format_exception(e)}")
        @display_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-show-404", session[:language])
      elsif forbidden?(e)
        Chef::Log.debug("API service returned 403 attempting to show org #{org_id}\n#{format_exception(e)}")
        @display_message = Mixlib::Localization::Messages.get_parse_error_message("opscode-chef-webui-organizations-show-403", session[:language])
      else
        Chef::Log.debug("API service returned error attempting to show org #{org_id}\n#{format_exception(e)}")
        raise
      end
    end
  end

  def chargify_payment_url(sub_id)
    message = "update_payment--#{sub_id}--#{Chef::Config[:chargify_hosted_page_secret]}"
    token = Digest::SHA1.hexdigest(message)[0..9]
    "https://#{Chef::Config[:chargify_site]}.chargify.com/update_payment/#{sub_id}/#{token}?opscode_site=manage"
  end

end
