namespace LingoRoad.Domain;

/// FSRS-4.5 scheduler, default weights, target retention 0.9 (interval == stability).
public static class Fsrs
{
    private static readonly double[] W =
    [
        0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031,
        1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755
    ];
    private const double Decay = -0.5;
    private const double Factor = 19.0 / 81.0;

    public static double Retrievability(double days, double stability) =>
        Math.Pow(1.0 + Factor * days / stability, Decay);

    private static double InitStability(Grade g) => Math.Max(W[(int)g - 1], 0.1);

    private static double InitDifficulty(Grade g) =>
        Math.Clamp(W[4] - ((int)g - 3) * W[5], 1.0, 10.0);

    private static double NextDifficulty(double d, Grade g)
    {
        var next = d - W[6] * ((int)g - 3);
        return Math.Clamp(W[7] * InitDifficulty(Grade.Easy) + (1 - W[7]) * next, 1.0, 10.0);
    }

    private static double RecallStability(double d, double s, double r, Grade g) =>
        s * (1 + Math.Exp(W[8]) * (11 - d) * Math.Pow(s, -W[9])
               * (Math.Exp(W[10] * (1 - r)) - 1)
               * (g == Grade.Hard ? W[15] : 1.0)
               * (g == Grade.Easy ? W[16] : 1.0));

    private static double ForgetStability(double d, double s, double r) =>
        Math.Min(W[11] * Math.Pow(d, -W[12]) * (Math.Pow(s + 1, W[13]) - 1)
                 * Math.Exp(W[14] * (1 - r)), s);

    public static void Review(ReviewCard card, Grade grade, DateTime now)
    {
        if (card.State == "new")
        {
            card.Stability = InitStability(grade);
            card.Difficulty = InitDifficulty(grade);
        }
        else
        {
            var days = Math.Max((now - (card.LastReview ?? now)).TotalDays, 0);
            var r = Retrievability(days, card.Stability);
            card.Difficulty = NextDifficulty(card.Difficulty, grade);
            card.Stability = grade == Grade.Again
                ? ForgetStability(card.Difficulty, card.Stability, r)
                : RecallStability(card.Difficulty, card.Stability, r, grade);
        }

        card.Reps++;
        card.LastReview = now;
        if (grade == Grade.Again)
        {
            card.State = "relearning";
            card.Due = now.AddMinutes(10);
        }
        else
        {
            card.State = "review";
            card.Due = now.AddDays(Math.Max(card.Stability, 1.0));
        }
    }
}
