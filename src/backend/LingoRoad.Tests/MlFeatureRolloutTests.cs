using LingoRoad.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

namespace LingoRoad.Tests;

public class MlFeatureRolloutTests
{
    [Fact]
    public void Production_defaults_to_disabled_and_development_to_enabled()
    {
        var configuration = new ConfigurationBuilder().Build();

        Assert.False(MlFeatureRollout.IsEnabled(configuration,
            Environment(Environments.Production), "Speaking", Guid.NewGuid()));
        Assert.True(MlFeatureRollout.IsEnabled(configuration,
            Environment(Environments.Development), "Speaking", Guid.NewGuid()));
    }

    [Fact]
    public void Cohort_assignment_is_stable_for_same_user()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["MlFeatures:SpeakingRolloutPercent"] = "25"
            }).Build();
        var userId = Guid.NewGuid();
        var environment = Environment(Environments.Production);

        var first = MlFeatureRollout.IsEnabled(configuration, environment,
            "Speaking", userId);
        Assert.Equal(first, MlFeatureRollout.IsEnabled(configuration, environment,
            "Speaking", userId));
    }

    private static IWebHostEnvironment Environment(string name) =>
        new TestEnvironment { EnvironmentName = name };

    private sealed class TestEnvironment : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "LingoRoad.Tests";
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
        public string WebRootPath { get; set; } = string.Empty;
        public string EnvironmentName { get; set; } = Environments.Development;
        public string ContentRootPath { get; set; } = string.Empty;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
