using QuestGraph.Data;
using QuestGraph.Domain;

namespace QuestGraph.Services;

public class MasteryService(AppDbContext db)
{
    public async Task RecordAnswerAsync(Guid userId, int skillId, bool correct)
    {
        var m = await db.Masteries.FindAsync(userId, skillId);
        if (m is null)
        {
            m = new Mastery { UserId = userId, SkillId = skillId };
            db.Masteries.Add(m);
        }
        var days = (DateTime.UtcNow - m.UpdatedAt).TotalDays;
        m.PCorrect = MasteryCalc.Update(m.PCorrect, correct, days);
        m.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
    }
}
