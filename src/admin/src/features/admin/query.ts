import { useCallback, useEffect, useRef, useState } from 'react'
import { api, ApiError } from '../../lib/api'

export interface QueryState<T> { data?: T; error?: ApiError; loading: boolean; reload: () => Promise<void> }

export function useQuery<T>(path: string): QueryState<T> {
  const [data, setData] = useState<T>(); const [error, setError] = useState<ApiError>(); const [loading, setLoading] = useState(true)
  const requestId = useRef(0); const controller = useRef<AbortController | undefined>(undefined)
  const reload = useCallback(async () => {
    controller.current?.abort(); const currentController = new AbortController(); controller.current = currentController; const currentId = ++requestId.current
    setLoading(true); setError(undefined)
    try { const next = await api<T>(path, { signal:currentController.signal }); if (currentId === requestId.current) setData(next) }
    catch (reason) { if (currentId === requestId.current && !(reason instanceof DOMException && reason.name === 'AbortError')) setError(reason instanceof ApiError ? reason : new ApiError(0, 'unexpected_error')) }
    finally { if (currentId === requestId.current) setLoading(false) }
  }, [path])
  // requestId invalidation is intentionally performed during cleanup to guard unmounts.
  // oxlint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { void reload(); const activeController = controller.current; return () => { requestId.current++; activeController?.abort() } }, [reload])
  return { data, error, loading, reload }
}
