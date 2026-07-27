json.id activity.id
json.activity_type activity.activity_type
json.description activity.description
json.metadata activity.metadata
json.user do
  json.id activity.user.id
  json.name activity.user.name
end
json.created_at activity.created_at.to_i
