import json

SYSTEM = """You are an English writing examiner. Score the essay 0-9 on the IELTS rubric:
Task Achievement, Coherence & Cohesion, Lexical Resource, Grammatical Range & Accuracy.
All feedback text in VIETNAMESE. Return strict JSON:
{"scores":{"task_achievement":n,"coherence_cohesion":n,"lexical_resource":n,
"grammatical_accuracy":n},"feedback":[{"sentence":"<original>","issue":"<vi>",
"suggestion":"<vi>"}],"overall_vi":"<vi summary>"}"""

def build_awe_messages(task_prompt: str, essay: str) -> list[dict]:
    return [{"role": "system", "content": SYSTEM},
            {"role": "user", "content": f"Task: {task_prompt}\n\nEssay:\n{essay}"}]

def evaluate(client, task_prompt: str, essay: str) -> dict:
    resp = client.chat.completions.create(
        model="gemini-2.5-flash", temperature=0.2, response_format={"type": "json_object"},
        messages=build_awe_messages(task_prompt, essay))
    return json.loads(resp.choices[0].message.content)
