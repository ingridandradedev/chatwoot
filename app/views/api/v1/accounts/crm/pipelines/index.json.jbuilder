json.meta do
  json.count @pipelines.size
end

json.payload do
  json.array! @pipelines do |pipeline|
    json.partial! 'api/v1/accounts/crm/pipelines/pipeline', pipeline: pipeline
  end
end
