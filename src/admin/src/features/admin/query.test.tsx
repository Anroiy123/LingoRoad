import { render, screen, waitFor } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { useQuery } from './query'

const View = ({ path }: { path: string }) => { const query = useQuery<{ value:string }>(path); return <div>{query.loading ? 'loading' : query.data?.value}</div> }

describe('useQuery', () => {
  it('không để response cũ ghi đè khi path thay đổi', async () => {
    let resolveFirst!: (value: Response) => void
    vi.spyOn(globalThis, 'fetch').mockImplementation((input) => String(input).endsWith('/first') ? new Promise((resolve) => { resolveFirst = resolve }) : Promise.resolve(new Response(JSON.stringify({ value:'new' }), { status:200, headers:{ 'Content-Type':'application/json' } })))
    const view = render(<View path="/first" />); view.rerender(<View path="/second" />)
    await waitFor(() => expect(screen.getByText('new')).toBeTruthy())
    resolveFirst(new Response(JSON.stringify({ value:'old' }), { status:200, headers:{ 'Content-Type':'application/json' } }))
    await new Promise((resolve) => setTimeout(resolve, 0)); expect(screen.queryByText('old')).toBeNull(); expect(screen.getByText('new')).toBeTruthy()
  })
})
