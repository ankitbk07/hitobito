# encoding: utf-8

class Event::RegisterController < ApplicationController
  
  helper_method :resource, :entry, :group, :event
  
  before_filter :assert_external_application_possible
  before_filter :assert_honeypot_is_empty, only: [:check, :register]
  
  def index
    flash.now[:notice] = "Du musst dich einloggen um dich für den Anlass '#{event.to_s}' anzumelden."
  end
  
  def check
    if params[:person][:email].present?
      if user = Person.find_by_email(params[:person][:email])
        user.generate_reset_password_token!
        # send email
        flash.now[:notice] = "Wir haben dich in unserer Datenbank gefunden.\n\n" + 
                             "Wir haben dir ein E-Mail mit einem Link geschickt, " + 
                             "wo du dich direkt für den Anlass anmelden kannst."
        render 'index'
      else
        @person = Person.new(email: params[:person][:email])
        flash.now[:notice] = "Bitte fülle das folgende Formular aus, bevor du dich für den Anlass anmeldest."
        render 'register'
      end
    else
      flash.now[:alert] = 'Bitte gibt eine Emailadresse ein'
      render 'index'
    end
  end
  
  def register
    if create_person
      sign_in(:person, person)
      flash[:notice] = 'Deine Daten wurden aufgenommen. Du kannst dich nun für den Anlass anmelden.'
      redirect_to group_event_path(group, event)
    else
      render 'register'
    end
  end
  
  private
  
  def assert_external_application_possible
    if event.application_possible?
      if current_user
        redirect_to group_event_path(group, event)
      else
        # supports external applications?
      end
      
    else
      flash[:alert] = "Das Anmeldefenster für diesen Anlass ist geschlossen."
      
      if current_user
        redirect_to group_event_path(group, event)
      else
        redirect_to new_person_session_path
      end
    end
  end
  
  def assert_honeypot_is_empty
    if params[:name].present?
      redirect_to new_person_session_path
    end
  end
  
  def create_person
    person.attributes = params[:person]
    person.save
  end
  
  def person
    @person ||= Person.new
  end
  
  alias entry person
  alias resource person
  
  def event
    @event ||= group.events.find(params[:id])
  end
  
  def group
    @group ||= Group.find(params[:group_id])
  end
    
  def devise_controller?
    true  # hence, no login required
  end
  
  
end