import pipelineAPI from '../pipelines';
import ApiClient from '../../ApiClient';

describe('#PipelineAPI', () => {
  it('creates correct instance', () => {
    expect(pipelineAPI).toBeInstanceOf(ApiClient);
    expect(pipelineAPI).toHaveProperty('get');
    expect(pipelineAPI).toHaveProperty('show');
    expect(pipelineAPI).toHaveProperty('create');
    expect(pipelineAPI).toHaveProperty('update');
    expect(pipelineAPI).toHaveProperty('delete');
  });

  it('uses correct endpoint and accountScoped option', () => {
    expect(pipelineAPI.resource).toBe('crm/pipelines');
    expect(pipelineAPI.options.accountScoped).toBe(true);
  });
});
