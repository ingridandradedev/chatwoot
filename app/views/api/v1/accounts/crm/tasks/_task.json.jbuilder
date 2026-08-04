json.id task.id
json.title task.title
json.description task.description
json.assignee do
  json.id task.assignee.id
  json.name task.assignee.name
end
json.contact do
  json.id task.contact.id
  json.name task.contact.name
end
json.created_by do
  json.id task.created_by.id
  json.name task.created_by.name
end
json.due_date task.due_date.to_i
json.reminder_at task.reminder_at&.to_i
json.reminded task.reminded
json.priority task.priority
json.status task.status
json.completed_at task.completed_at&.to_i
json.completed_by_id task.completed_by_id
json.created_by_id task.created_by_id
json.contact_id task.contact_id
json.created_at task.created_at.to_i
json.updated_at task.updated_at.to_i
