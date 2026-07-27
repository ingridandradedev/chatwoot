json.meta do
  json.count @activities.total_count
  json.current_page @activities.current_page
end

json.payload do
  json.array! @activities do |activity|
    json.partial! 'api/v1/accounts/crm/activities/activity', activity: activity
  end
end
