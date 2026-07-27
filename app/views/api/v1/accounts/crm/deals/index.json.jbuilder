json.meta do
  json.count @deals.total_count
  json.current_page @deals.current_page
end

json.payload do
  json.array! @deals do |deal|
    json.partial! 'api/v1/accounts/crm/deals/deal', deal: deal
  end
end
