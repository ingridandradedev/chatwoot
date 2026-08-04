# app/controllers/api/v1/accounts/crm/calendar_feed_controller.rb
module Api::V1::Accounts::Crm
  class CalendarFeedController < Api::V1::Accounts::BaseController
    skip_before_action :authenticate_user!
    before_action :authenticate_by_user_token!

    def show
      tasks = Crm::Task.where(account: Current.account, assignee: @user)
                       .pending_and_overdue
                       .includes(:contact)
                       .order(due_date: :asc)

      calendar = generate_ical(tasks)

      response.headers['Content-Type'] = 'text/calendar; charset=utf-8'
      response.headers['Content-Disposition'] = 'inline; filename="crm-tasks.ics"'
      render plain: calendar
    end

    private

    def authenticate_by_user_token!
      token = params[:user_token]
      @user = User.find_by(access_token: token) if token.present?

      render plain: 'Unauthorized', status: :unauthorized unless @user
    end

    def generate_ical(tasks)
      lines = []
      lines << 'BEGIN:VCALENDAR'
      lines << 'VERSION:2.0'
      lines << 'PRODID:-//Chatwoot CRM//Tasks//EN'
      lines << 'CALSCALE:GREGORIAN'
      lines << 'METHOD:PUBLISH'
      lines << 'X-WR-CALNAME:CRM Tasks'

      tasks.each do |task|
        lines << generate_vevent(task)
      end

      lines << 'END:VCALENDAR'
      lines.join("\r\n")
    end

    def generate_vevent(task)
      dtstart = format_datetime(task.due_date)
      dtend = format_datetime(task.due_date + 30.minutes)
      description = build_description(task)
      priority = ical_priority(task.priority)

      [
        'BEGIN:VEVENT',
        "UID:crm-task-#{task.id}@chatwoot",
        "DTSTART:#{dtstart}",
        "DTEND:#{dtend}",
        "SUMMARY:#{escape_ical(task.title)}",
        "DESCRIPTION:#{escape_ical(description)}",
        "PRIORITY:#{priority}",
        "STATUS:CONFIRMED",
        task.reminder_at ? "BEGIN:VALARM\r\nTRIGGER:-PT#{reminder_minutes(task)}M\r\nACTION:DISPLAY\r\nDESCRIPTION:#{escape_ical(task.title)}\r\nEND:VALARM" : nil,
        'END:VEVENT'
      ].compact.join("\r\n")
    end

    def format_datetime(dt)
      dt.utc.strftime('%Y%m%dT%H%M%SZ')
    end

    def escape_ical(text)
      return '' if text.blank?

      text.gsub('\\', '\\\\').gsub(',', '\,').gsub(';', '\;').gsub("\n", '\n')
    end

    def build_description(task)
      parts = []
      parts << task.description if task.description.present?
      parts << "Contato: #{task.contact.name}" if task.contact&.name.present?
      parts << "Prioridade: #{task.priority}"
      parts.join(' | ')
    end

    def ical_priority(priority)
      case priority
      when 'high' then 1
      when 'medium' then 5
      when 'low' then 9
      else 5
      end
    end

    def reminder_minutes(task)
      return 15 unless task.reminder_at && task.due_date

      ((task.due_date - task.reminder_at) / 60).to_i.clamp(1, 10_080)
    end
  end
end
