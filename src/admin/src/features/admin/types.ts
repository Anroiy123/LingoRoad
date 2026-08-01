export interface Skill {
  id: number
  code: string
  name: string
  nameVi: string
  category: string
  parentId: number | null
  cefrLevel: string
}

export interface Item {
  id: string
  stableId: string | null
  skillId: number
  skillCode: string
  cefrLevel: string
  type: string
  stem: string
  options: string[]
  correctAnswer: string
  explanationVi: string | null
  source: string
  license: string | null
  reviewer: string | null
  contentVersion: string | null
  a: number
  b: number
  c: number
  audioUrl: string | null
}

export interface Lesson {
  id: string
  stableId: string
  slug: string
  title: string
  titleVi: string
  descriptionVi: string | null
  skillId: number
  skillCode: string
  cefrLevel: string
  order: number
  isPublished: boolean
  itemIds: string[]
}

export interface Analytics {
  learners: number
  activeLearners: number
  completedLessons: number
  answers: number
  correctAnswers: number
  correctness: number
  dueReviews: number
  content: { skills: number; lessons: number; publishedLessons: number; items: number }
  mastery: { category: string; average: number }[]
}

export interface AuditEvent {
  id: number
  action: string
  entityType: string
  entityId: string
  createdAt: string
}
