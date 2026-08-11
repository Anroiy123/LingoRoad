using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using LingoRoad.Data;
using LingoRoad.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LingoRoad.Tests;

public class QuestionReviewEndpointTests : IClassFixture<TestAppFactory>
{
    private readonly TestAppFactory _factory;

    public QuestionReviewEndpointTests(TestAppFactory factory) => _factory = factory;

    private async Task<(HttpClient Client, Guid UserId)> RegisterAsync()
    {
        var client = _factory.CreateClient();
        var email = $"{Guid.NewGuid():N}@question-review.test";
        var response = await client.PostAsJsonAsync("/auth/register",
            new { email, password = "secret123", name = "Question reviewer" });
        response.EnsureSuccessStatusCode();
        var token = (await response.Content.ReadFromJsonAsync<Dictionary<string, string>>())!["token"];
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        return (client, await db.Users.Where(x => x.Email == email).Select(x => x.Id).SingleAsync());
    }

    private static async Task<ReviewCard> AddLessonMistakeAsync(AppDbContext db, Guid userId,
        int skillId, string type = "mcq", DateTime? due = null, bool correct = false,
        string answer = "blue", string? explanation = "Giai thich", string stem = "What color?")
    {
        var suffix = Guid.NewGuid().ToString("N");
        var lesson = new Lesson
        {
            Id = Guid.NewGuid(), StableId = $"question-review-{suffix}", Slug = $"question-review-{suffix}",
            Title = "Question review", TitleVi = "On tap cau hoi", SkillId = skillId, CefrLevel = "A1",
            Order = 1000, ContentVersion = "test", ContentChecksum = suffix, Source = "test",
            License = "test", Reviewer = "test",
        };
        var attempt = new LessonAttempt { UserId = userId, LessonId = lesson.Id, StartOperationId = Guid.NewGuid() };
        var exercise = new Exercise
        {
            UserId = userId, LessonAttemptId = attempt.Id, SkillId = skillId, CefrLevel = "A1", Type = type,
            Stem = stem, OptionsJson = "[\"red\",\"green\"]", CorrectAnswer = answer,
            ExplanationVi = explanation, IsCorrect = correct, AnsweredAt = DateTime.UtcNow,
        };
        var card = new ReviewCard
        {
            UserId = userId, SkillId = skillId, SourceExerciseId = exercise.Id,
            Front = stem, Back = answer, Due = due ?? DateTime.UtcNow.AddMinutes(-1),
        };
        db.AddRange(lesson, attempt, exercise, card);
        await db.SaveChangesAsync();
        return card;
    }

    private async Task<int> SkillIdAsync()
    {
        using var scope = _factory.Services.CreateScope();
        return await scope.ServiceProvider.GetRequiredService<AppDbContext>().Skills
            .Select(x => x.Id).FirstAsync();
    }

    [Fact]
    public async Task Questions_due_returns_only_owned_due_wrong_supported_lesson_cards_in_due_order_without_answers()
    {
        var (client, userId) = await RegisterAsync();
        var skillId = await SkillIdAsync();
        var now = DateTime.UtcNow;
        var expected = new List<ReviewCard>();
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            for (var index = 0; index < 12; index++)
                expected.Add(await AddLessonMistakeAsync(db, userId, skillId, due: now.AddMinutes(-index - 1),
                    answer: "secret-answer", explanation: "secret-explanation", stem: $"Stem {index}"));
            await AddLessonMistakeAsync(db, userId, skillId, type: "writing", due: now.AddMinutes(-1));
            await AddLessonMistakeAsync(db, userId, skillId, correct: true, due: now.AddMinutes(-1));
            await AddLessonMistakeAsync(db, userId, skillId, due: now.AddMinutes(1));
            db.ReviewCards.Add(new ReviewCard { UserId = userId, SkillId = skillId, SourceExerciseId = Guid.NewGuid(),
                Front = "missing source", Back = "nope", Due = now.AddMinutes(-1) });
            await db.SaveChangesAsync();
        }
        var (_, otherUserId) = await RegisterAsync();
        using (var scope = _factory.Services.CreateScope())
            await AddLessonMistakeAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), otherUserId, skillId);

        var response = await client.GetAsync("/reviews/questions/due?limit=10");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        using var json = JsonDocument.Parse(body);
        var root = json.RootElement;
        Assert.Equal(12, root.GetProperty("totalDue").GetInt32());
        var items = root.GetProperty("items");
        Assert.Equal(10, items.GetArrayLength());
        Assert.Equal(expected[11].Id, items[0].GetProperty("id").GetGuid());
        Assert.Equal("mcq", items[0].GetProperty("type").GetString());
        Assert.True(items[0].TryGetProperty("options", out _));
        Assert.False(body.Contains("secret-answer", StringComparison.OrdinalIgnoreCase));
        Assert.False(body.Contains("secret-explanation", StringComparison.OrdinalIgnoreCase));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(11)]
    public async Task Questions_due_rejects_limits_outside_one_to_ten(int limit)
    {
        var (client, _) = await RegisterAsync();

        var response = await client.GetAsync($"/reviews/questions/due?limit={limit}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Check_normalizes_answer_and_is_read_only()
    {
        var (client, userId) = await RegisterAsync();
        var skillId = await SkillIdAsync();
        ReviewCard card;
        using (var scope = _factory.Services.CreateScope())
            card = await AddLessonMistakeAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), userId, skillId,
                answer: "Blue", explanation: "Vi xanh duoc dung");

        var response = await client.PostAsJsonAsync($"/reviews/{card.Id}/check", new { answer = "  blue  " });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("\"correct\":true", body, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("\"correctAnswer\":\"Blue\"", body, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Vi xanh duoc dung", body, StringComparison.Ordinal);
        using var verifyScope = _factory.Services.CreateScope();
        var db = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(0, await db.ReviewGradeOperations.CountAsync(x => x.CardId == card.Id));
        Assert.Equal(0, await db.LearningEvents.CountAsync(x => x.ExerciseId == card.SourceExerciseId));
        Assert.Equal(0, await db.Masteries.CountAsync(x => x.UserId == userId && x.SkillId == skillId));
    }

    [Fact]
    public async Task Check_enforces_non_empty_answer_ownership_and_due_state()
    {
        var (client, userId) = await RegisterAsync();
        var skillId = await SkillIdAsync();
        ReviewCard dueCard;
        ReviewCard futureCard;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            dueCard = await AddLessonMistakeAsync(db, userId, skillId);
            futureCard = await AddLessonMistakeAsync(db, userId, skillId, due: DateTime.UtcNow.AddMinutes(1));
        }
        var (_, otherUserId) = await RegisterAsync();
        ReviewCard otherCard;
        using (var scope = _factory.Services.CreateScope())
            otherCard = await AddLessonMistakeAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), otherUserId, skillId);

        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.PostAsJsonAsync($"/reviews/{dueCard.Id}/check", new { answer = " " })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict,
            (await client.PostAsJsonAsync($"/reviews/{futureCard.Id}/check", new { answer = "blue" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.PostAsJsonAsync($"/reviews/{otherCard.Id}/check", new { answer = "blue" })).StatusCode);
    }

    [Fact]
    public async Task Question_grade_requires_answer_and_rating_matching_recomputed_correctness_then_records_reward_mastery_and_replay()
    {
        var (client, userId) = await RegisterAsync();
        var skillId = await SkillIdAsync();
        ReviewCard wrongCard;
        ReviewCard correctCard;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            wrongCard = await AddLessonMistakeAsync(db, userId, skillId, answer: "blue");
            correctCard = await AddLessonMistakeAsync(db, userId, skillId, answer: "green");
        }

        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync($"/reviews/{wrongCard.Id}/grade",
            new { rating = 1, operationId = Guid.NewGuid(), expectedReps = 0 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync($"/reviews/{wrongCard.Id}/grade",
            new { answer = "red", rating = 3, operationId = Guid.NewGuid(), expectedReps = 0 })).StatusCode);
        var operationId = Guid.NewGuid();
        var request = new { answer = " red ", rating = 1, operationId, expectedReps = 0 };
        var grade = await client.PostAsJsonAsync($"/reviews/{wrongCard.Id}/grade", request);
        var replay = await client.PostAsJsonAsync($"/reviews/{wrongCard.Id}/grade", request);
        var changed = await client.PostAsJsonAsync($"/reviews/{wrongCard.Id}/grade",
            new { answer = "blue", rating = 1, operationId, expectedReps = 0 });
        Assert.Equal(HttpStatusCode.OK, grade.StatusCode);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, changed.StatusCode);
        Assert.Contains("\"xp\":5", await grade.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
        Assert.Contains("\"coins\":1", await replay.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
        using (var firstVerifyScope = _factory.Services.CreateScope())
        {
            var firstVerifyDb = firstVerifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
            var wrongOperation = await firstVerifyDb.ReviewGradeOperations.SingleAsync(x => x.OperationId == operationId);
            Assert.Equal("red", wrongOperation.SubmittedAnswer);
            Assert.False(wrongOperation.Correct);
            var wrongCardAfterGrade = await firstVerifyDb.ReviewCards.SingleAsync(x => x.Id == wrongCard.Id);
            Assert.Equal(1, wrongCardAfterGrade.Reps);
            Assert.Equal("relearning", wrongCardAfterGrade.State);
            Assert.True(wrongCardAfterGrade.Due > wrongCardAfterGrade.LastReview);
            Assert.InRange((await firstVerifyDb.Masteries.SingleAsync(x =>
                x.UserId == userId && x.SkillId == skillId)).PCorrect, 0.34, 0.36);
            var wrongReward = await firstVerifyDb.RewardLedgerEntries.SingleAsync(x =>
                x.SourceOperationId == operationId);
            Assert.Equal(5, wrongReward.Xp);
            Assert.Equal(1, wrongReward.Coins);
        }

        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync($"/reviews/{correctCard.Id}/grade",
            new { answer = "GREEN", rating = 1, operationId = Guid.NewGuid(), expectedReps = 0 })).StatusCode);
        var correctGrade = await client.PostAsJsonAsync($"/reviews/{correctCard.Id}/grade",
            new { answer = " GREEN ", rating = 2, operationId = Guid.NewGuid(), expectedReps = 0 });
        Assert.Equal(HttpStatusCode.OK, correctGrade.StatusCode);
        var stale = await client.PostAsJsonAsync($"/reviews/{correctCard.Id}/grade",
            new { answer = "green", rating = 2, operationId = Guid.NewGuid(), expectedReps = 1 });
        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);

        using var verifyScope = _factory.Services.CreateScope();
        var verifyDb = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        var operations = await verifyDb.ReviewGradeOperations.Where(x => x.UserId == userId).ToListAsync();
        Assert.Equal(2, operations.Count);
        var correctOperation = Assert.Single(operations, x => x.CardId == correctCard.Id);
        Assert.Equal("GREEN", correctOperation.SubmittedAnswer);
        Assert.True(correctOperation.Correct);
        var rewards = await verifyDb.RewardLedgerEntries.Where(x => x.UserId == userId).ToListAsync();
        Assert.Equal(2, rewards.Count);
        Assert.All(rewards, reward => { Assert.Equal(5, reward.Xp); Assert.Equal(1, reward.Coins); });
        Assert.Equal(2, await verifyDb.LearningEvents.CountAsync(x => x.UserId == userId && x.EventType == LearningEventTypes.ReviewGraded));
        var mastery = await verifyDb.Masteries.SingleAsync(x => x.UserId == userId && x.SkillId == skillId);
        Assert.InRange(mastery.PCorrect, 0.54, 0.56);
        var correctCardAfterGrade = await verifyDb.ReviewCards.SingleAsync(x => x.Id == correctCard.Id);
        Assert.Equal(1, correctCardAfterGrade.Reps);
        Assert.Equal("review", correctCardAfterGrade.State);
        Assert.True(correctCardAfterGrade.Due > correctCardAfterGrade.LastReview);
    }

    [Fact]
    public async Task Legacy_manual_card_still_accepts_rating_only_grade()
    {
        var (client, _) = await RegisterAsync();
        var created = await client.PostAsJsonAsync("/reviews/cards",
            new { skillCode = "vocabulary.everyday", front = "manual", back = "thu cong" });
        var id = JsonDocument.Parse(await created.Content.ReadAsStringAsync()).RootElement.GetProperty("id").GetGuid();

        var grade = await client.PostAsJsonAsync($"/reviews/{id}/grade",
            new { rating = 3, operationId = Guid.NewGuid(), expectedReps = 0 });

        Assert.Equal(HttpStatusCode.OK, grade.StatusCode);
    }

    [Fact]
    public async Task Legacy_source_backed_unsupported_lesson_card_still_accepts_rating_only_grade()
    {
        var (client, userId) = await RegisterAsync();
        var skillId = await SkillIdAsync();
        ReviewCard card;
        using (var scope = _factory.Services.CreateScope())
            card = await AddLessonMistakeAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), userId,
                skillId, type: "listening_mcq");

        var grade = await client.PostAsJsonAsync($"/reviews/{card.Id}/grade",
            new { rating = 3, operationId = Guid.NewGuid(), expectedReps = 0 });

        Assert.Equal(HttpStatusCode.OK, grade.StatusCode);
    }

    [Fact]
    public async Task Question_grade_same_operation_is_safe_when_submitted_concurrently()
    {
        var (client, userId) = await RegisterAsync();
        var skillId = await SkillIdAsync();
        ReviewCard card;
        using (var scope = _factory.Services.CreateScope())
            card = await AddLessonMistakeAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), userId, skillId);
        var operationId = Guid.NewGuid();
        var request = new { answer = "red", rating = 1, operationId, expectedReps = 0 };
        using var concurrentClient = _factory.CreateClient();
        concurrentClient.DefaultRequestHeaders.Authorization = client.DefaultRequestHeaders.Authorization;

        var responses = await Task.WhenAll(
            client.PostAsJsonAsync($"/reviews/{card.Id}/grade", request),
            concurrentClient.PostAsJsonAsync($"/reviews/{card.Id}/grade", request));

        Assert.All(responses, response => Assert.Equal(HttpStatusCode.OK, response.StatusCode));
        using var verifyScope = _factory.Services.CreateScope();
        var db = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.ReviewGradeOperations.CountAsync(x => x.OperationId == operationId));
        Assert.Equal(1, await db.RewardLedgerEntries.CountAsync(x => x.SourceOperationId == operationId));
        Assert.Equal(1, await db.Masteries.CountAsync(x => x.UserId == userId && x.SkillId == skillId));
    }
}
