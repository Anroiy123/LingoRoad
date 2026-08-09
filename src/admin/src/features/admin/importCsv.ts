import Papa from 'papaparse'
import type { AdminImportRequest } from './types'

export const importCsvHeaders = [
  'kind', 'version', 'source', 'license', 'reviewer', 'code', 'name', 'nameVi',
  'category', 'parentCode', 'cefrLevel', 'stableId', 'skillCode', 'type', 'stem',
  'options', 'correctAnswer', 'explanationVi', 'slug', 'title', 'titleVi',
  'descriptionVi', 'order', 'isPublished', 'itemStableIds',
] as const

type CsvRow = Record<(typeof importCsvHeaders)[number], string>

const required = (row: CsvRow, field: keyof CsvRow, line: number): string => {
  const value = row[field]?.trim()
  if (!value) throw new Error(`CSV dòng ${line}: thiếu cột ${field}.`)
  return value
}

const optional = (value: string | undefined): string | null => value?.trim() || null

const array = (value: string | undefined, field: string, line: number): string[] => {
  try {
    const parsed: unknown = JSON.parse(value?.trim() || '[]')
    if (!Array.isArray(parsed) || parsed.some((entry) => typeof entry !== 'string')) throw new Error()
    const normalized = parsed.map((entry) => entry.trim())
    if (normalized.some((entry) => !entry)) throw new Error()
    return normalized
  } catch {
    throw new Error(`CSV dòng ${line}: ${field} phải là mảng JSON gồm các chuỗi không rỗng.`)
  }
}

export function parseImportCsv(csv: string): AdminImportRequest {
  const parsed = Papa.parse<CsvRow>(csv, { header: true, skipEmptyLines: 'greedy', transformHeader: (header) => header.trim() })
  if (parsed.errors.length) {
    const issue = parsed.errors[0]
    throw new Error(`CSV${typeof issue.row === 'number' ? ` dòng ${issue.row + 2}` : ''}: ${issue.message}`)
  }
  const fields = parsed.meta.fields ?? []
  const missing = importCsvHeaders.filter((header) => !fields.includes(header))
  const unknown = fields.filter((header) => !importCsvHeaders.includes(header as (typeof importCsvHeaders)[number]))
  if (missing.length || unknown.length) {
    const details = [missing.length ? `thiếu ${missing.join(', ')}` : '', unknown.length ? `không hỗ trợ ${unknown.join(', ')}` : ''].filter(Boolean).join('; ')
    throw new Error(`Header CSV không hợp lệ: ${details}.`)
  }
  if (!parsed.data.length) throw new Error('CSV không có dòng nội dung.')

  const first = parsed.data[0]
  const bundle: AdminImportRequest = {
    version: required(first, 'version', 2),
    source: required(first, 'source', 2),
    license: required(first, 'license', 2),
    reviewer: required(first, 'reviewer', 2),
    skills: [], items: [], lessons: [],
  }
  const metadata = ['version', 'source', 'license', 'reviewer'] as const
  parsed.data.forEach((row, index) => {
    const line = index + 2
    for (const field of metadata) {
      const value = row[field]?.trim()
      if (value && value !== bundle[field]) throw new Error(`CSV dòng ${line}: ${field} không khớp metadata của bundle.`)
    }
    const kind = required(row, 'kind', line).toLowerCase()
    if (kind === 'skill') {
      bundle.skills.push({ code: required(row, 'code', line), name: required(row, 'name', line), nameVi: required(row, 'nameVi', line), category: required(row, 'category', line), parentCode: optional(row.parentCode), cefrLevel: required(row, 'cefrLevel', line) })
      return
    }
    if (kind === 'item') {
      bundle.items.push({ stableId: required(row, 'stableId', line), skillCode: required(row, 'skillCode', line), cefrLevel: required(row, 'cefrLevel', line), type: required(row, 'type', line), stem: required(row, 'stem', line), options: array(row.options, 'options', line), correctAnswer: required(row, 'correctAnswer', line), explanationVi: optional(row.explanationVi) })
      return
    }
    if (kind === 'lesson') {
      const order = Number(required(row, 'order', line)); if (!Number.isInteger(order)) throw new Error(`CSV dòng ${line}: order phải là số nguyên.`)
      const published = required(row, 'isPublished', line).toLowerCase(); if (!['true', 'false'].includes(published)) throw new Error(`CSV dòng ${line}: isPublished phải là true hoặc false.`)
      bundle.lessons.push({ stableId: required(row, 'stableId', line), slug: required(row, 'slug', line), title: required(row, 'title', line), titleVi: required(row, 'titleVi', line), descriptionVi: optional(row.descriptionVi), skillCode: required(row, 'skillCode', line), cefrLevel: required(row, 'cefrLevel', line), order, isPublished: published === 'true', itemStableIds: array(row.itemStableIds, 'itemStableIds', line) })
      return
    }
    throw new Error(`CSV dòng ${line}: kind "${kind}" không hợp lệ; chỉ hỗ trợ skill, item hoặc lesson.`)
  })
  return bundle
}

export const importCsvExample = Papa.unparse({ fields:[...importCsvHeaders], data:[
  ['skill','2026.08.09-csv-v1','LingoRoad Admin CSV','Proprietary','Content reviewer','grammar.example','Example skill','Kỹ năng mẫu','grammar','','A1','','','','','','','','','','','','','',''],
  ['item','','','','','','','','','','A1','item-example-01','grammar.example','mcq','Choose the correct answer, please.','["Answer A","Answer B"]','Answer A','Giải thích mẫu','','','','','','',''],
  ['lesson','','','','','','','','','','A1','lesson-example-01','grammar.example','','','','','','example-lesson','Example lesson','Bài học mẫu','Mô tả mẫu','1','true','["item-example-01"]'],
] })
