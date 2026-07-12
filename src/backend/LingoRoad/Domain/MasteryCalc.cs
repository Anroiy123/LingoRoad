namespace LingoRoad.Domain;

/// EMA update with Ebbinghaus-style decay toward the 0.5 uninformed baseline.
public static class MasteryCalc
{
    private const double DecayRate = 0.03;   // per day
    private const double LearningRate = 0.3;

    public static double Update(double prior, bool correct, double daysSinceLast)
    {
        var decayed = 0.5 + (prior - 0.5) * Math.Exp(-DecayRate * Math.Max(0, daysSinceLast));
        var target = correct ? 1.0 : 0.0;
        return Math.Clamp(decayed + LearningRate * (target - decayed), 0.0, 1.0);
    }
}
