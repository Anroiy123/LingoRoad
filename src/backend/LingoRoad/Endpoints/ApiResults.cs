namespace LingoRoad.Endpoints;

public static class ApiResults
{
    public static IResult MlUnavailable() =>
        Results.Json(new { error = "ml_service_unavailable" }, statusCode: 503);
}
