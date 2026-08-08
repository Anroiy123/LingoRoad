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
  contentVersion: string | null
  source: string
  license: string | null
  reviewer: string | null
  updatedAt: string
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
  itemUsage: { itemId: string; attempts: number; correctness: number }[]
}

export interface AuditEvent {
  id: number
  action: string
  entityType: string
  entityId: string
  createdAt: string
  adminUserId: string
  detail?: string | null
}

export interface AdminUser {
  id: string
  email: string
  name: string | null
  role: string
  targetCefr: string | null
  createdAt: string
}

export interface UserListResponse { total: number; users: AdminUser[] }

export interface UserDetail extends AdminUser {
  mastery: { skillCode: string; skillName: string; pCorrect: number; updatedAt: string }[]
  activity: { lessonsCompleted: number; exercisesAnswered: number; exercisesCorrect: number; dueReviews: number; lastActiveAt: string | null }
}

export interface SampleMetric { key: string; samples: number; status: string; correctness: number | null }
export interface LearningQuality {
  generatedAt: string
  minimumSampleSize: number
  calibration: { samples: number; status: string; meanPredicted: number | null; observedCorrectness: number | null; brierScore: number | null }
  byCefr: SampleMetric[]
  bySkill: SampleMetric[]
  byItem: SampleMetric[]
  byLesson: SampleMetric[]
  drift: { recentSamples: number; baselineSamples: number; status: string; recentCorrectness: number | null; baselineCorrectness: number | null; delta: number | null }
  fairness: { samples: number; status: string; reason: string }
}

export type GeneratedItem = Pick<Item, 'id' | 'skillId' | 'skillCode' | 'cefrLevel' | 'type' | 'stem' | 'options' | 'correctAnswer' | 'explanationVi' | 'source' | 'a' | 'b' | 'c'>
export interface GeneratedItemsResponse { generated: number; items: GeneratedItem[] }

export interface ImportPreview {
  valid: boolean
  checksum: string
  counts: { skills: number; items: number; lessons: number }
  errors: string[]
}
