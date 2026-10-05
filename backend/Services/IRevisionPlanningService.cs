namespace backend.Services;

public interface IRevisionPlanningService
{
    Task TriggerAsync(int tripRequestId, string revisionComment, string authorizationHeader, CancellationToken cancellationToken = default);
}
