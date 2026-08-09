namespace LingoRoad.Domain;

/// Fixed-interval spaced repetition for saved words: day 1, 3, 7, 14 since
/// first save, expressed as gaps between consecutive stages. Deliberately
/// not FSRS — no grading input, and the anchor for each gap is the actual
/// review moment (rolling), not the original CreatedAt (absolute).
public static class SavedWordSchedule
{
    private static readonly int[] GapDays = [1, 2, 4, 7];

    public static DateTime InitialDue(DateTime createdAt) =>
        createdAt.AddDays(GapDays[0]);

    /// Mutates word in place. Returns true if word.ReviewStage was already
    /// the final stage (4, "day 14") — caller should delete the row
    /// (mastered) instead of persisting further changes.
    public static bool Advance(SavedWord word, DateTime now)
    {
        if (word.ReviewStage >= GapDays.Length) return true;
        word.NextReviewAt = now.AddDays(GapDays[word.ReviewStage]);
        word.ReviewStage++;
        return false;
    }
}
