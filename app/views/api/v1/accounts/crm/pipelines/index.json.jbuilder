json.meta do
  json.count @pipelines.size
end

json.payload do
  json.array! @pipelines do |pipeline|
    json.partial! 'api/v1/accounts/crm/pipelines/pipeline', pipeline: pipeline
    json.stages do
      json.array! pipeline.stages.ordered do |stage|
        json.partial! 'api/v1/accounts/crm/stages/stage', stage: stage
      end
    end
  end
end
