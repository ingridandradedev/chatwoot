json.meta do
  json.count @tasks.total_count
  json.current_page @tasks.current_page
end

json.payload do
  json.array! @tasks do |task|
    json.partial! 'api/v1/accounts/crm/tasks/task', task: task
  end
end
