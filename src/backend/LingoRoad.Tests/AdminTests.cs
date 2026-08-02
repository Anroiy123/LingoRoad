using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using LingoRoad.Data;
using LingoRoad.Domain;
using LingoRoad.Endpoints;

namespace LingoRoad.Tests;

public class AdminTests : IClassFixture<TestAppFactory>
{
    private readonly TestAppFactory _factory;
    public AdminTests(TestAppFactory factory) => _factory = factory;

    [Fact]
    public async Task Admin_routes_require_authentication_and_admin_role()
    {
        using var anonymous = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await anonymous.GetAsync("/admin/analytics/overview")).StatusCode);

        using var learner = await TestAuth.ClientAsync(_factory, UserRoles.Learner);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await learner.GetAsync("/admin/analytics/overview")).StatusCode);

        using var admin = await TestAuth.ClientAsync(_factory);
        Assert.Equal(HttpStatusCode.OK,
            (await admin.GetAsync("/admin/analytics/overview")).StatusCode);
    }

    [Fact]
    public async Task Admin_can_create_content_and_relationships_block_unsafe_delete()
    {
        using var client = await TestAuth.ClientAsync(_factory);
        var suffix = Guid.NewGuid().ToString("N");
        var skillResponse = await client.PostAsJsonAsync("/admin/skills", new
        {
            code = $"grammar.admin_{suffix}",
            name = "Admin grammar",
            nameVi = "Ngữ pháp quản trị",
            category = "grammar",
            cefrLevel = "A1"
        });
        Assert.Equal(HttpStatusCode.Created, skillResponse.StatusCode);
        var skillId = (await Json(skillResponse)).GetProperty("id").GetInt32();
        Assert.Equal(HttpStatusCode.NoContent, (await client.PutAsJsonAsync($"/admin/skills/{skillId}", new
        {
            code = $"grammar.admin_{suffix}",
            name = "Admin grammar updated",
            nameVi = "Ngữ pháp quản trị",
            category = "grammar",
            cefrLevel = "A1"
        })).StatusCode);
        var childResponse = await client.PostAsJsonAsync("/admin/skills", new
        {
            code = $"grammar.admin_child_{suffix}",
            name = "Admin child",
            nameVi = "Kỹ năng con",
            category = "grammar",
            parentId = skillId,
            cefrLevel = "A1"
        });
        childResponse.EnsureSuccessStatusCode();
        var childId = (await Json(childResponse)).GetProperty("id").GetInt32();
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PutAsJsonAsync($"/admin/skills/{skillId}", new
        {
            code = $"grammar.admin_{suffix}",
            name = "Admin grammar updated",
            nameVi = "Ngữ pháp quản trị",
            category = "grammar",
            parentId = childId,
            cefrLevel = "A1"
        })).StatusCode);

        var itemResponse = await client.PostAsJsonAsync("/admin/items", new
        {
            stableId = $"item-{suffix}",
            skillId,
            cefrLevel = "A1",
            type = "mcq",
            stem = "Choose one",
            options = new[] { "A", "B" },
            correctAnswer = "A",
            source = "Admin test",
            a = 1,
            b = -2,
            c = .5
        });
        Assert.Equal(HttpStatusCode.Created, itemResponse.StatusCode);
        var itemId = (await Json(itemResponse)).GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.NoContent, (await client.PutAsJsonAsync($"/admin/items/{itemId}", new
        {
            stableId = $"item-{suffix}",
            skillId,
            cefrLevel = "A1",
            type = "mcq",
            stem = "Choose one updated",
            options = new[] { "A", "B" },
            correctAnswer = "A",
            source = "Admin test",
            a = 1,
            b = -2,
            c = .5
        })).StatusCode);

        var lessonResponse = await client.PostAsJsonAsync("/admin/lessons", new
        {
            stableId = $"lesson-{suffix}",
            slug = $"lesson-{suffix}",
            title = "Admin lesson",
            titleVi = "Bài quản trị",
            skillId,
            cefrLevel = "A1",
            order = 999,
            isPublished = false,
            itemIds = new[] { itemId }
        });
        Assert.Equal(HttpStatusCode.Created, lessonResponse.StatusCode);
        var lessonId = (await Json(lessonResponse)).GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.NoContent, (await client.PutAsJsonAsync($"/admin/lessons/{lessonId}", new
        {
            stableId = $"lesson-{suffix}",
            slug = $"lesson-{suffix}",
            title = "Admin lesson",
            titleVi = "Bài quản trị cập nhật",
            skillId,
            cefrLevel = "A1",
            order = 999,
            isPublished = true,
            itemIds = new[] { itemId }
        })).StatusCode);

        var lessonsBeforeDelete = await client.GetStringAsync("/admin/lessons");
        Assert.Contains("Bài quản trị cập nhật", lessonsBeforeDelete);

        Assert.Equal(HttpStatusCode.Conflict,
            (await client.DeleteAsync($"/admin/items/{itemId}")).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict,
            (await client.DeleteAsync($"/admin/skills/{skillId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.DeleteAsync($"/admin/lessons/{lessonId}")).StatusCode);

        var lessons = await client.GetStringAsync("/admin/lessons");
        Assert.DoesNotContain($"lesson-{suffix}", lessons);
    }

    [Fact]
    public async Task Import_validate_apply_is_transactional_versioned_and_idempotent()
    {
        using var client = await TestAuth.ClientAsync(_factory);
        var suffix = Guid.NewGuid().ToString("N");
        var invalid = Import(suffix, itemSkillCode: "missing.skill");
        var preview = await client.PostAsJsonAsync("/admin/imports/validate", invalid);
        preview.EnsureSuccessStatusCode();
        Assert.False((await Json(preview)).GetProperty("valid").GetBoolean());
        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.PostAsJsonAsync("/admin/imports", invalid)).StatusCode);

        var cycle = new
        {
            version = $"cycle-{suffix}", source = "Admin import test", license = "Test",
            reviewer = "Reviewer",
            skills = new[]
            {
                new { code = $"cycle.a_{suffix}", name = "A", nameVi = "A", category = "grammar",
                    parentCode = $"cycle.b_{suffix}", cefrLevel = "A1" },
                new { code = $"cycle.b_{suffix}", name = "B", nameVi = "B", category = "grammar",
                    parentCode = $"cycle.a_{suffix}", cefrLevel = "A1" }
            },
            items = Array.Empty<object>(), lessons = Array.Empty<object>()
        };
        var cyclePreview = await client.PostAsJsonAsync("/admin/imports/validate", cycle);
        cyclePreview.EnsureSuccessStatusCode();
        Assert.Contains("parent_cycle", (await cyclePreview.Content.ReadAsStringAsync()));

        var empty = new
        {
            version = $"empty-{suffix}", source = "Admin import test", license = "Test",
            reviewer = "Reviewer", skills = Array.Empty<object>(), items = Array.Empty<object>(),
            lessons = Array.Empty<object>()
        };
        var emptyPreview = await client.PostAsJsonAsync("/admin/imports/validate", empty);
        emptyPreview.EnsureSuccessStatusCode();
        Assert.Contains("content_required", await emptyPreview.Content.ReadAsStringAsync());

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.False(await db.Items.AnyAsync(x => x.StableId == $"item-import-{suffix}"));
        }

        var valid = Import(suffix);
        var apply = await client.PostAsJsonAsync("/admin/imports", valid);
        apply.EnsureSuccessStatusCode();
        Assert.False((await Json(apply)).GetProperty("replay").GetBoolean());
        var replay = await client.PostAsJsonAsync("/admin/imports", valid);
        replay.EnsureSuccessStatusCode();
        Assert.True((await Json(replay)).GetProperty("replay").GetBoolean());

        var changed = Import(suffix, stem: "Changed payload");
        Assert.Equal(HttpStatusCode.Conflict,
            (await client.PostAsJsonAsync("/admin/imports", changed)).StatusCode);
    }

    [Fact]
    public async Task Analytics_and_audit_return_real_admin_activity()
    {
        using var client = await TestAuth.ClientAsync(_factory);
        var suffix = Guid.NewGuid().ToString("N");
        var create = await client.PostAsJsonAsync("/admin/skills", new
        {
            code = $"vocabulary.audit_{suffix}",
            name = "Audit",
            nameVi = "Nhật ký",
            category = "vocabulary",
            cefrLevel = "A1"
        });
        create.EnsureSuccessStatusCode();

        var analytics = await client.GetFromJsonAsync<JsonElement>("/admin/analytics/overview");
        Assert.True(analytics.GetProperty("content").GetProperty("skills").GetInt32() > 0);
        var audit = await client.GetStringAsync("/admin/audit?limit=10");
        Assert.Contains($"vocabulary.audit_{suffix}", audit);
    }

    [Fact]
    public async Task Learning_quality_requires_admin_and_labels_small_samples()
    {
        using var learner = await TestAuth.ClientAsync(_factory, UserRoles.Learner);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await learner.GetAsync("/admin/analytics/learning-quality")).StatusCode);

        using var admin = await TestAuth.ClientAsync(_factory);
        var report = await admin.GetFromJsonAsync<JsonElement>(
            "/admin/analytics/learning-quality");

        Assert.Equal("insufficient_sample",
            report.GetProperty("calibration").GetProperty("status").GetString());
        Assert.Equal("insufficient_sample",
            report.GetProperty("drift").GetProperty("status").GetString());
        Assert.Equal("insufficient_sample",
            report.GetProperty("fairness").GetProperty("status").GetString());
        Assert.Equal(30, report.GetProperty("minimumSampleSize").GetInt32());
    }

    private static object Import(string suffix, string? itemSkillCode = null,
        string stem = "Imported question")
    {
        var skillCode = $"grammar.import_{suffix}";
        var itemId = $"item-import-{suffix}";
        return new
        {
            version = $"test-{suffix}",
            source = "Admin import test",
            license = "Test",
            reviewer = "Reviewer",
            skills = new[] { new { code = skillCode, name = "Import", nameVi = "Nhập",
                category = "grammar", parentCode = (string?)null, cefrLevel = "A1" } },
            items = new[] { new { stableId = itemId, skillCode = itemSkillCode ?? skillCode,
                cefrLevel = "A1", type = "mcq", stem, options = new[] { "A", "B" },
                correctAnswer = "A", explanationVi = "Giải thích" } },
            lessons = new[] { new { stableId = $"lesson-import-{suffix}",
                slug = $"lesson-import-{suffix}", title = "Import", titleVi = "Nhập",
                descriptionVi = "Test", skillCode, cefrLevel = "A1", order = 1000,
                isPublished = false, itemStableIds = new[] { itemId } } }
        };
    }

    private static async Task<JsonElement> Json(HttpResponseMessage response) =>
        JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement.Clone();
}
