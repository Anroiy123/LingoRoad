using System.Security.Cryptography;

namespace LingoRoad.Services;

public static class MlFeatureRollout
{
    public static bool IsEnabled(IConfiguration configuration,
        IWebHostEnvironment environment, string feature, Guid userId)
    {
        var configured = configuration.GetValue<int?>(
            $"MlFeatures:{feature}RolloutPercent");
        var percentage = Math.Clamp(configured ??
            (environment.IsProduction() ? 0 : 100), 0, 100);
        if (percentage is 0 or 100) return percentage == 100;
        var hash = SHA256.HashData(userId.ToByteArray());
        return BitConverter.ToUInt32(hash, 0) % 100 < percentage;
    }
}
