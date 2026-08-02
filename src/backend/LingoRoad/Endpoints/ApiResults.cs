using LingoRoad.Services;

namespace LingoRoad.Endpoints;

public static class ApiResults
{
    public static IResult Error(string code) =>
        Results.BadRequest(new { error = code });

    public static IResult MlUnavailable() =>
        Results.Json(new { error = "ml_service_unavailable" }, statusCode: 503);

    public static IResult MlRejected(MlInputRejectedException error) =>
        Results.Json(new { error = error.Error }, statusCode: error.StatusCode);

    public static IResult FeatureDisabled() =>
        Results.Json(new { error = "feature_disabled" }, statusCode: 503);
}
