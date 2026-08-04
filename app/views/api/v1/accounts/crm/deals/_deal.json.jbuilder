json.id deal.id
json.title deal.title
json.value deal.value.to_f
json.stage_id deal.stage_id
json.contact do
  json.id deal.contact.id
  json.name deal.contact.name
  json.email deal.contact.email
  json.phone_number deal.contact.phone_number
  json.thumbnail deal.contact.avatar_url
  json.company deal.contact.company&.name
  json.last_activity_at deal.contact.last_activity_at&.to_i
  json.custom_attributes deal.contact.custom_attributes
end
json.created_by_id deal.created_by_id
json.created_at deal.created_at.to_i
json.updated_at deal.updated_at.to_i
