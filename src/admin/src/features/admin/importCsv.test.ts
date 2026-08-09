import { describe, expect, it } from 'vitest'
import { importCsvExample, importCsvHeaders, parseImportCsv } from './importCsv'

describe('parseImportCsv', () => {
  it('đọc bundle và giữ quoted comma, newline, escaped quote', () => {
    const csv = importCsvExample.replace('Choose the correct answer, please.', 'Choose ""one"",\nplease.')
    const result = parseImportCsv(csv)
    expect(result.version).toBe('2026.08.09-csv-v1')
    expect(result.skills).toHaveLength(1); expect(result.items).toHaveLength(1); expect(result.lessons).toHaveLength(1)
    expect(result.items[0].stem).toBe('Choose "one",\nplease.')
    expect(result.items[0].options).toEqual(['Answer A', 'Answer B'])
    expect(result.lessons[0].itemStableIds).toEqual(['item-example-01'])
  })

  it('báo header thiếu hoặc không hỗ trợ', () => {
    expect(() => parseImportCsv('kind,version\nskill,v1')).toThrow('Header CSV không hợp lệ')
    expect(() => parseImportCsv(`${importCsvHeaders.join(',')},extra\nskill,v,s,l,r,c,n,nv,g,,A1,,,,,,,,,,,,,,,x`)).toThrow('không hỗ trợ extra')
  })

  it('báo kind và mảng JSON không hợp lệ', () => {
    expect(() => parseImportCsv(importCsvExample.replace('\nskill,', '\nunknown,'))).toThrow('kind "unknown" không hợp lệ')
    expect(() => parseImportCsv(importCsvExample.replace('"[""Answer A"",""Answer B""]"', 'Answer A'))).toThrow('options phải là mảng JSON')
  })

  it('trim phần tử mảng và từ chối phần tử rỗng sau khi trim', () => {
    const normalized = parseImportCsv(importCsvExample
      .replace('"[""Answer A"",""Answer B""]"', '"[""  Answer A  "","" Answer B ""]"')
      .replace('"[""item-example-01""]"', '"["" item-example-01 ""]"'))
    expect(normalized.items[0].options).toEqual(['Answer A','Answer B']); expect(normalized.lessons[0].itemStableIds).toEqual(['item-example-01'])
    expect(() => parseImportCsv(importCsvExample.replace('"[""Answer A"",""Answer B""]"', '"[""Answer A"",""   ""]"'))).toThrow('options phải là mảng JSON')
    expect(() => parseImportCsv(importCsvExample.replace('"[""item-example-01""]"', '"[""  ""]"'))).toThrow('itemStableIds phải là mảng JSON')
  })

  it('báo order, boolean và metadata không hợp lệ', () => {
    expect(() => parseImportCsv(importCsvExample.replace(',1,true,', ',1.5,true,'))).toThrow('order phải là số nguyên')
    expect(() => parseImportCsv(importCsvExample.replace(',1,true,', ',1,yes,'))).toThrow('isPublished phải là true hoặc false')
    expect(() => parseImportCsv(importCsvExample.replace('\nitem,,,,', '\nitem,,Nguồn khác,,'))).toThrow('source không khớp metadata')
  })
})
